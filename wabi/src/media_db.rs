use rusqlite::{Connection, OptionalExtension, params};
use serde::Serialize;
use std::fs;
use std::os::unix::fs as unixfs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

pub const SCHEMA_VERSION: i32 = 2;
pub const THUMB_SIZE: u32 = 256;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AssetType {
    Screenshot,
    Recording,
}

impl AssetType {
    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "screenshot" => Some(Self::Screenshot),
            "recording" => Some(Self::Recording),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Screenshot => "screenshot",
            Self::Recording => "recording",
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct ProbeResult {
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub duration_ms: Option<i32>,
}

#[derive(Serialize, Clone, Debug)]
pub struct Asset {
    pub id: i64,
    #[serde(rename = "type")]
    pub asset_type: String,
    pub source_path: String,
    pub thumbnail_path: String,
    pub created_at: i64,
    pub deleted: bool,
    pub file_size: Option<i64>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub duration_ms: Option<i32>,
}

#[derive(Serialize, Clone, Debug)]
pub struct OcrItem {
    pub id: i64,
    #[serde(rename = "type")]
    pub item_type: String,
    pub detail: String,
    pub created_at: i64,
}

pub fn cache_dir() -> PathBuf {
    dirs_cache_home().join("quickshell/media_popup")
}

pub fn thumbnails_dir() -> PathBuf {
    cache_dir().join("thumbnails")
}

pub fn db_path() -> PathBuf {
    config_dir().join("assets.db")
}

pub fn config_dir() -> PathBuf {
    dirs_config_home().join("quickshell/media_popup")
}

fn dirs_cache_home() -> PathBuf {
    std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".cache")))
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn dirs_config_home() -> PathBuf {
    std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn now_millis() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

pub fn open() -> Result<Connection, rusqlite::Error> {
    let path = db_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::create_dir_all(thumbnails_dir());
    let conn = Connection::open(&path)?;
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.pragma_update(None, "synchronous", "NORMAL")?;
    conn.pragma_update(None, "foreign_keys", "ON")?;
    conn.pragma_update(None, "temp_store", "MEMORY")?;
    init_schema(&conn)?;
    Ok(conn)
}

fn init_schema(conn: &Connection) -> Result<(), rusqlite::Error> {
    conn.execute_batch(
        r#"
        CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY);
        CREATE TABLE IF NOT EXISTS assets (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            asset_type      TEXT    NOT NULL CHECK(asset_type IN ('screenshot','recording')),
            source_path     TEXT    NOT NULL UNIQUE,
            thumbnail_path  TEXT    NOT NULL,
            created_at      INTEGER NOT NULL,
            deleted_at      INTEGER,
            file_size       INTEGER,
            width           INTEGER,
            height          INTEGER,
            duration_ms     INTEGER
        );
        CREATE TABLE IF NOT EXISTS colors (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            hex        TEXT    NOT NULL,
            picked_at  INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS ocr_history (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            detail      TEXT    NOT NULL,
            created_at  INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_assets_created_at ON assets(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_colors_picked_at  ON colors(picked_at DESC);
        CREATE INDEX IF NOT EXISTS idx_ocr_created_at ON ocr_history(created_at DESC);
        "#,
    )?;

    let version: Option<i32> = conn
        .query_row("SELECT version FROM schema_version LIMIT 1", [], |r| {
            r.get(0)
        })
        .optional()?;
    let needs_migration = version.is_none() || version.unwrap_or(0) < SCHEMA_VERSION;

    if needs_migration {
        migrate_legacy(conn);
        conn.execute(
            "INSERT OR REPLACE INTO schema_version (version) VALUES (?1)",
            params![SCHEMA_VERSION],
        )?;
    }
    Ok(())
}

fn migrate_legacy(conn: &Connection) {
    let legacy_path = dirs_cache_home().join("quickshell_media_history.json");
    if !legacy_path.exists() {
        return;
    }
    let Ok(content) = fs::read_to_string(&legacy_path) else {
        return;
    };
    let Ok(value) = serde_json::from_str::<serde_json::Value>(&content) else {
        return;
    };
    let Some(entries) = value.get("history").and_then(|v| v.as_array()) else {
        return;
    };

    for entry in entries {
        let Some(asset_type) = entry.get("type").and_then(|v| v.as_str()) else {
            continue;
        };
        if asset_type != "screenshot" && asset_type != "recording" {
            continue;
        }
        let Some(detail) = entry.get("detail").and_then(|v| v.as_str()) else {
            continue;
        };
        let _ = add_asset(conn, asset_type, detail);
    }

    let backup = legacy_path.with_extension("json.migrated");
    let _ = fs::rename(&legacy_path, &backup);
}

pub fn thumbnail_path_for(id: i64) -> PathBuf {
    thumbnails_dir().join(format!("{id}.png"))
}

fn probe(source: &Path) -> ProbeResult {
    let mut result = ProbeResult::default();
    let output = Command::new("ffprobe")
        .args(["-v", "quiet", "-print_format", "json", "-show_streams"])
        .arg(source)
        .output();
    let Ok(out) = output else {
        return result;
    };
    if !out.status.success() {
        return result;
    }
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&out.stdout) else {
        return result;
    };
    let streams = value.get("streams").and_then(|v| v.as_array());
    let Some(streams) = streams else {
        return result;
    };
    for stream in streams {
        if stream.get("codec_type").and_then(|v| v.as_str()) != Some("video") {
            continue;
        }
        result.width = stream
            .get("width")
            .and_then(|v| v.as_i64())
            .map(|v| v as i32);
        result.height = stream
            .get("height")
            .and_then(|v| v.as_i64())
            .map(|v| v as i32);
        if let Some(dur) = stream.get("duration").and_then(|v| v.as_str())
            && let Ok(secs) = dur.parse::<f64>()
        {
            result.duration_ms = Some((secs * 1000.0) as i32);
        }
        break;
    }
    result
}

pub fn add_asset(conn: &Connection, asset_type_str: &str, source: &str) -> Result<i64, String> {
    let asset_type = AssetType::parse(asset_type_str)
        .ok_or_else(|| format!("invalid asset type: {asset_type_str}"))?;
    let source_path = PathBuf::from(source);

    let file_size = fs::metadata(&source_path).ok().map(|m| m.len() as i64);
    let probe_result = if source_path.exists() {
        probe(&source_path)
    } else {
        ProbeResult::default()
    };

    let existing: Option<(i64, Option<i64>)> = conn
        .query_row(
            "SELECT id, deleted_at FROM assets WHERE source_path = ?1",
            params![source],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .optional()
        .map_err(|e| e.to_string())?;

    if let Some((id, _)) = existing {
        conn.execute(
            "UPDATE assets SET file_size = COALESCE(?1, file_size), width = COALESCE(?2, width), height = COALESCE(?3, height), duration_ms = COALESCE(?4, duration_ms), deleted_at = NULL WHERE id = ?5",
            params![file_size, probe_result.width, probe_result.height, probe_result.duration_ms, id],
        ).map_err(|e| e.to_string())?;
        ensure_thumbnail(&source_path, id, asset_type);
        return Ok(id);
    }

    let created_at = fs::metadata(&source_path)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_millis() as i64)
        .unwrap_or_else(now_millis);

    conn.execute(
        "INSERT INTO assets (asset_type, source_path, thumbnail_path, created_at, file_size, width, height, duration_ms) VALUES (?1, ?2, '', ?3, ?4, ?5, ?6, ?7)",
        params![
            asset_type.as_str(),
            source,
            created_at,
            file_size,
            probe_result.width,
            probe_result.height,
            probe_result.duration_ms,
        ],
    )
    .map_err(|e| e.to_string())?;
    let id = conn.last_insert_rowid();

    let thumb = thumbnail_path_for(id);
    conn.execute(
        "UPDATE assets SET thumbnail_path = ?1 WHERE id = ?2",
        params![thumb.to_string_lossy().to_string(), id],
    )
    .map_err(|e| e.to_string())?;
    ensure_thumbnail(&source_path, id, asset_type);
    Ok(id)
}

fn ensure_thumbnail(source: &Path, id: i64, asset_type: AssetType) {
    let thumb = thumbnail_path_for(id);
    if let Some(parent) = thumb.parent() {
        let _ = fs::create_dir_all(parent);
    }
    match asset_type {
        AssetType::Screenshot => {
            if thumb.exists() {
                return;
            }
            if source.exists() {
                let _ = fs::remove_file(&thumb);
                let _ = unixfs::symlink(source, &thumb);
            }
        }
        AssetType::Recording => {
            if thumb.exists() {
                return;
            }
            if !source.exists() {
                return;
            }
            let scale = format!("scale={THUMB_SIZE}:-2");
            let _ = Command::new("ffmpeg")
                .args(["-y", "-hide_banner", "-loglevel", "error", "-i"])
                .arg(source)
                .args(["-ss", "00:00:00.500", "-vframes", "1", "-vf", &scale])
                .arg(&thumb)
                .output();
        }
    }
}

pub fn remove_asset(conn: &Connection, asset_id: i64) -> Result<(), String> {
    let thumb: Option<String> = conn
        .query_row(
            "SELECT thumbnail_path FROM assets WHERE id = ?1",
            params![asset_id],
            |r| r.get(0),
        )
        .optional()
        .map_err(|e| e.to_string())?;
    if let Some(t) = thumb {
        let p = PathBuf::from(&t);
        if p.exists() {
            let _ = fs::remove_file(p);
        }
    }
    conn.execute("DELETE FROM assets WHERE id = ?1", params![asset_id])
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn clear_assets(conn: &Connection) -> Result<(), String> {
    let mut stmt = conn
        .prepare("SELECT thumbnail_path FROM assets")
        .map_err(|e| e.to_string())?;
    let thumbs: Vec<String> = stmt
        .query_map([], |r| r.get(0))
        .map_err(|e| e.to_string())?
        .filter_map(|r| r.ok())
        .collect();
    drop(stmt);
    for t in thumbs {
        let p = PathBuf::from(t);
        if p.exists() {
            let _ = fs::remove_file(p);
        }
    }
    conn.execute("DELETE FROM assets", [])
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn clear_all(conn: &Connection) -> Result<(), String> {
    clear_assets(conn)?;
    clear_ocr(conn)?;
    Ok(())
}

pub fn check_deleted(conn: &Connection) -> Result<(), String> {
    let now = now_millis();
    let limit_24h = now - 24 * 3600 * 1000;

    conn.execute("BEGIN TRANSACTION", []).map_err(|e| e.to_string())?;

    if let Err(e) = conn.execute(
        "DELETE FROM assets WHERE deleted_at IS NOT NULL AND deleted_at < ?1",
        params![limit_24h],
    ) {
        let _ = conn.execute("ROLLBACK", []);
        return Err(e.to_string());
    }

    let mut stmt = match conn.prepare("SELECT id, source_path, deleted_at FROM assets") {
        Ok(s) => s,
        Err(e) => {
            let _ = conn.execute("ROLLBACK", []);
            return Err(e.to_string());
        }
    };
    let rows: Vec<(i64, String, Option<i64>)> = match stmt
        .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?))) {
            Ok(iter) => iter.filter_map(|r| r.ok()).collect(),
            Err(e) => {
                let _ = conn.execute("ROLLBACK", []);
                return Err(e.to_string());
            }
        };
    drop(stmt);

    for (id, source, deleted_at) in rows {
        let exists = PathBuf::from(&source).exists();
        if exists && deleted_at.is_some() {
            if let Err(e) = conn.execute(
                "UPDATE assets SET deleted_at = NULL WHERE id = ?1",
                params![id],
            ) {
                let _ = conn.execute("ROLLBACK", []);
                return Err(e.to_string());
            }
        } else if !exists && deleted_at.is_none() {
            if let Err(e) = conn.execute(
                "UPDATE assets SET deleted_at = ?1 WHERE id = ?2",
                params![now, id],
            ) {
                let _ = conn.execute("ROLLBACK", []);
                return Err(e.to_string());
            }
        }
    }

    conn.execute("COMMIT", []).map_err(|e| e.to_string())?;
    Ok(())
}

pub fn list_assets(
    conn: &Connection,
    search: Option<&str>,
    limit: i64,
) -> Result<Vec<Asset>, String> {
    let mut sql = String::from(
        "SELECT a.id, a.asset_type, a.source_path, a.thumbnail_path, a.created_at, a.deleted_at, a.file_size, a.width, a.height, a.duration_ms \
         FROM assets a",
    );
    let mut conditions: Vec<String> = Vec::new();
    let mut binds: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();

    if let Some(s) = search.filter(|s| !s.is_empty()) {
        let idx = binds.len() + 1;
        conditions.push(format!("a.source_path LIKE ?{idx} ESCAPE '\\'"));
        let pattern = format!(
            "%{}%",
            s.replace('\\', "\\\\")
                .replace('%', "\\%")
                .replace('_', "\\_")
        );
        binds.push(Box::new(pattern));
    }

    if !conditions.is_empty() {
        sql.push_str(" WHERE ");
        sql.push_str(&conditions.join(" AND "));
    }
    sql.push_str(" ORDER BY a.created_at DESC LIMIT ?");
    let limit_idx = binds.len() + 1;
    sql.push_str(&limit_idx.to_string());
    binds.push(Box::new(limit));

    let mut params_refs: Vec<&dyn rusqlite::ToSql> = Vec::with_capacity(binds.len());
    for b in &binds {
        params_refs.push(b.as_ref());
    }

    let mut stmt = conn.prepare(&sql).map_err(|e| e.to_string())?;
    let asset_iter = stmt
        .query_map(params_refs.as_slice(), |r| {
            Ok((
                r.get::<_, i64>(0)?,
                r.get::<_, String>(1)?,
                r.get::<_, String>(2)?,
                r.get::<_, String>(3)?,
                r.get::<_, i64>(4)?,
                r.get::<_, Option<i64>>(5)?,
                r.get::<_, Option<i64>>(6)?,
                r.get::<_, Option<i32>>(7)?,
                r.get::<_, Option<i32>>(8)?,
                r.get::<_, Option<i32>>(9)?,
            ))
        })
        .map_err(|e| e.to_string())?;

    let mut assets: Vec<Asset> = Vec::new();
    for row in asset_iter {
        let (
            id,
            asset_type,
            source_path,
            thumbnail_path,
            created_at,
            deleted_at,
            file_size,
            width,
            height,
            duration_ms,
        ) = row.map_err(|e| e.to_string())?;
        let asset = Asset {
            id,
            asset_type,
            source_path,
            thumbnail_path,
            created_at,
            deleted: deleted_at.is_some(),
            file_size,
            width,
            height,
            duration_ms,
        };
        assets.push(asset);
    }
    Ok(assets)
}

#[derive(Serialize, Clone, Debug)]
pub struct PickedColor {
    pub id: i64,
    pub hex: String,
    pub picked_at: i64,
}

pub fn add_color(conn: &Connection, hex: &str) -> Result<i64, String> {
    let hex = hex.trim().to_lowercase();
    if !hex.starts_with('#') || (hex.len() != 7 && hex.len() != 9) {
        return Err(format!("invalid hex color: {hex}"));
    }
    let now = now_millis();
    conn.execute(
        "INSERT INTO colors (hex, picked_at) VALUES (?1, ?2)",
        params![hex, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(conn.last_insert_rowid())
}

pub fn remove_color(conn: &Connection, id: i64) -> Result<(), String> {
    let rows = conn
        .execute("DELETE FROM colors WHERE id = ?1", params![id])
        .map_err(|e| e.to_string())?;
    if rows == 0 {
        return Err(format!("color id {id} not found"));
    }
    Ok(())
}

pub fn clear_colors(conn: &Connection) -> Result<(), String> {
    conn.execute("DELETE FROM colors", [])
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn list_colors(conn: &Connection, limit: i64) -> Result<Vec<PickedColor>, String> {
    let mut stmt = conn
        .prepare("SELECT id, hex, picked_at FROM colors ORDER BY picked_at DESC LIMIT ?1")
        .map_err(|e| e.to_string())?;
    let iter = stmt
        .query_map(params![limit], |r| {
            Ok(PickedColor {
                id: r.get(0)?,
                hex: r.get(1)?,
                picked_at: r.get(2)?,
            })
        })
        .map_err(|e| e.to_string())?;
    Ok(iter.flatten().collect())
}

pub fn add_ocr(conn: &Connection, detail: &str) -> Result<i64, String> {
    let now = now_millis();
    conn.execute(
        "INSERT INTO ocr_history (detail, created_at) VALUES (?1, ?2)",
        params![detail, now],
    )
    .map_err(|e| e.to_string())?;
    Ok(conn.last_insert_rowid())
}

pub fn list_ocr(conn: &Connection, limit: i64) -> Result<Vec<OcrItem>, String> {
    let mut stmt = conn
        .prepare("SELECT id, detail, created_at FROM ocr_history ORDER BY created_at DESC LIMIT ?1")
        .map_err(|e| e.to_string())?;
    let iter = stmt
        .query_map(params![limit], |r| {
            Ok(OcrItem {
                id: r.get(0)?,
                item_type: "ocr".to_string(),
                detail: r.get(1)?,
                created_at: r.get(2)?,
            })
        })
        .map_err(|e| e.to_string())?;
    Ok(iter.flatten().collect())
}

pub fn clear_ocr(conn: &Connection) -> Result<(), String> {
    conn.execute("DELETE FROM ocr_history", [])
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    fn open_mem() -> Connection {
        let conn = Connection::open_in_memory().unwrap();
        conn.pragma_update(None, "foreign_keys", "ON").unwrap();
        conn.pragma_update(None, "temp_store", "MEMORY").unwrap();
        conn
    }

    #[test]
    fn asset_type_parse_roundtrip() {
        assert_eq!(AssetType::parse("screenshot"), Some(AssetType::Screenshot));
        assert_eq!(AssetType::parse("recording"), Some(AssetType::Recording));
        assert_eq!(AssetType::parse("unknown"), None);
        assert_eq!(AssetType::parse(""), None);
        assert_eq!(AssetType::Screenshot.as_str(), "screenshot");
        assert_eq!(AssetType::Recording.as_str(), "recording");
    }

    #[test]
    fn schema_creates_all_tables_and_indexes() {
        let conn = open_mem();
        init_schema(&conn).unwrap();

        // Verify tables exist by inserting/querying
        conn.execute(
            "INSERT INTO assets (asset_type, source_path, thumbnail_path, created_at) VALUES ('screenshot', '/tmp/test.png', '', 1000)",
            [],
        ).unwrap();

        conn.execute(
            "INSERT INTO colors (hex, picked_at) VALUES ('#ff0000', 2000)",
            [],
        )
        .unwrap();

        conn.execute(
            "INSERT INTO ocr_history (detail, created_at) VALUES ('test ocr', 3000)",
            [],
        )
        .unwrap();

        let asset_count: i64 = conn
            .query_row("SELECT COUNT(*) FROM assets", [], |r| r.get(0))
            .unwrap();
        let color_count: i64 = conn
            .query_row("SELECT COUNT(*) FROM colors", [], |r| r.get(0))
            .unwrap();
        let ocr_count: i64 = conn
            .query_row("SELECT COUNT(*) FROM ocr_history", [], |r| r.get(0))
            .unwrap();

        assert_eq!(asset_count, 1);
        assert_eq!(color_count, 1);
        assert_eq!(ocr_count, 1);

        let version: i32 = conn
            .query_row("SELECT version FROM schema_version", [], |r| r.get(0))
            .unwrap();
        assert_eq!(version, SCHEMA_VERSION);
    }

    #[test]
    fn schema_sets_version_correctly() {
        let conn = open_mem();
        init_schema(&conn).unwrap();

        let version: i32 = conn
            .query_row("SELECT version FROM schema_version LIMIT 1", [], |r| {
                r.get(0)
            })
            .unwrap();
        assert_eq!(version, SCHEMA_VERSION);
    }

    #[test]
    fn schema_null_dates_need_migration() {
        let conn = open_mem();
        // Create table manually without schema_version to simulate fresh DB
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS assets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                asset_type TEXT NOT NULL,
                source_path TEXT NOT NULL,
                thumbnail_path TEXT NOT NULL,
                created_at INTEGER NOT NULL
            );",
        )
        .unwrap();

        // init_schema should add schema_version and migrate
        init_schema(&conn).unwrap();

        let version: i32 = conn
            .query_row("SELECT version FROM schema_version LIMIT 1", [], |r| {
                r.get(0)
            })
            .unwrap();
        assert_eq!(version, SCHEMA_VERSION);
    }

    #[test]
    fn add_color_validates_hex_format() {
        let conn = open_mem();
        init_schema(&conn).unwrap();

        assert!(add_color(&conn, "#ff0000").is_ok());
        assert!(add_color(&conn, "#FF00FF").is_ok());
        assert!(add_color(&conn, "#12345678").is_ok());
        assert!(add_color(&conn, "ff0000").is_err());
        assert!(add_color(&conn, "#12345").is_err());
        assert!(add_color(&conn, "").is_err());
    }

    #[test]
    fn add_color_handles_whitespace() {
        let conn = open_mem();
        init_schema(&conn).unwrap();

        let id = add_color(&conn, "  #ff0000  ").unwrap();
        let color = list_colors(&conn, 1).unwrap();
        assert_eq!(color[0].hex, "#ff0000");
        assert_eq!(color[0].id, id);
    }

    #[test]
    fn remove_color_errors_on_nonexistent() {
        let conn = open_mem();
        init_schema(&conn).unwrap();

        assert!(remove_color(&conn, 999).is_err());
        assert!(remove_color(&conn, 0).is_err());
    }

    #[test]
    fn list_colors_returns_empty_for_new_db() {
        let conn = open_mem();
        init_schema(&conn).unwrap();

        let colors = list_colors(&conn, 10).unwrap();
        assert!(colors.is_empty());
    }

    #[test]
    fn add_and_list_ocr_roundtrip() {
        let conn = open_mem();
        init_schema(&conn).unwrap();

        let id = add_ocr(&conn, "Hello from image").unwrap();
        let items = list_ocr(&conn, 10).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, id);
        assert_eq!(items[0].detail, "Hello from image");
        assert_eq!(items[0].item_type, "ocr");
    }

    #[test]
    fn check_deleted_updates_deleted_at() {
        let conn = open_mem();
        init_schema(&conn).unwrap();

        // Add an asset pointing to a file that doesn't exist
        conn.execute(
            "INSERT INTO assets (asset_type, source_path, thumbnail_path, created_at) VALUES ('screenshot', '/tmp/certainly-not-a-real-file.png', '', 1000)",
            [],
        ).unwrap();

        check_deleted(&conn).unwrap();

        let deleted_at: Option<i64> = conn
            .query_row("SELECT deleted_at FROM assets WHERE source_path = '/tmp/certainly-not-a-real-file.png'", [], |r| r.get(0))
            .unwrap();
        assert!(deleted_at.is_some());
    }

    #[test]
    fn thumbnail_path_for_uses_correct_path() {
        let path = thumbnail_path_for(42);
        assert!(path.to_string_lossy().contains("42"));
        assert!(path.to_string_lossy().ends_with(".png"));
        assert!(path.to_string_lossy().contains("thumbnails"));
    }

    #[test]
    fn database_path_has_correct_extension() {
        let path = db_path();
        assert!(path.to_string_lossy().ends_with("assets.db"));
    }
}
