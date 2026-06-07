use rusqlite::{params, Connection, OptionalExtension};
use serde::Serialize;
use std::fs;
use std::os::unix::fs as unixfs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

pub const SCHEMA_VERSION: i32 = 1;
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
    pub tags: Vec<String>,
}

#[derive(Serialize, Clone, Debug)]
pub struct TagCount {
    pub name: String,
    pub count: i64,
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
        CREATE TABLE IF NOT EXISTS tags (
            id    INTEGER PRIMARY KEY AUTOINCREMENT,
            name  TEXT    NOT NULL UNIQUE COLLATE NOCASE
        );
        CREATE TABLE IF NOT EXISTS asset_tags (
            asset_id INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
            tag_id   INTEGER NOT NULL REFERENCES tags(id)   ON DELETE CASCADE,
            PRIMARY KEY (asset_id, tag_id)
        );
        CREATE INDEX IF NOT EXISTS idx_assets_created_at ON assets(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_asset_tags_tag    ON asset_tags(tag_id);
        "#,
    )?;

    let version: Option<i32> = conn
        .query_row("SELECT version FROM schema_version LIMIT 1", [], |r| r.get(0))
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
        .args([
            "-v", "quiet",
            "-print_format", "json",
            "-show_streams",
        ])
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
            && let Ok(secs) = dur.parse::<f64>() {
                result.duration_ms = Some((secs * 1000.0) as i32);
            }
        break;
    }
    result
}

pub fn add_asset(
    conn: &Connection,
    asset_type_str: &str,
    source: &str,
) -> Result<i64, String> {
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
                .args([
                    "-y",
                    "-hide_banner",
                    "-loglevel", "error",
                    "-i",
                ])
                .arg(source)
                .args([
                    "-ss", "00:00:00.500",
                    "-vframes", "1",
                    "-vf", &scale,
                ])
                .arg(&thumb)
                .output();
        }
    }
}

pub fn set_tags(conn: &Connection, asset_id: i64, tags: &[String]) -> Result<(), String> {
    let mut seen = std::collections::HashSet::new();
    let mut normalized: Vec<String> = Vec::new();
    for t in tags {
        let trimmed = t.trim();
        if trimmed.is_empty() {
            continue;
        }
        let key = trimmed.to_ascii_lowercase();
        if seen.insert(key) {
            normalized.push(trimmed.to_string());
        }
    }

    let tx = conn.unchecked_transaction().map_err(|e| e.to_string())?;
    for name in &normalized {
        tx.execute(
            "INSERT OR IGNORE INTO tags (name) VALUES (?1)",
            params![name],
        )
        .map_err(|e| e.to_string())?;
    }
    tx.execute(
        "DELETE FROM asset_tags WHERE asset_id = ?1",
        params![asset_id],
    )
    .map_err(|e| e.to_string())?;
    for name in &normalized {
        tx.execute(
            "INSERT INTO asset_tags (asset_id, tag_id) SELECT ?1, id FROM tags WHERE name = ?2 COLLATE NOCASE",
            params![asset_id, name],
        )
        .map_err(|e| e.to_string())?;
    }
    tx.commit().map_err(|e| e.to_string())?;
    Ok(())
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

pub fn clear_all(conn: &Connection) -> Result<(), String> {
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
    conn.execute("DELETE FROM tags", [])
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn check_deleted(conn: &Connection) -> Result<(), String> {
    let now = now_millis();
    let mut stmt = conn
        .prepare("SELECT id, source_path, deleted_at FROM assets")
        .map_err(|e| e.to_string())?;
    let rows: Vec<(i64, String, Option<i64>)> = stmt
        .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))
        .map_err(|e| e.to_string())?
        .filter_map(|r| r.ok())
        .collect();
    drop(stmt);
    for (id, source, deleted_at) in rows {
        let exists = PathBuf::from(&source).exists();
        if exists && deleted_at.is_some() {
            conn.execute(
                "UPDATE assets SET deleted_at = NULL WHERE id = ?1",
                params![id],
            )
            .map_err(|e| e.to_string())?;
        } else if !exists && deleted_at.is_none() {
            conn.execute(
                "UPDATE assets SET deleted_at = ?1 WHERE id = ?2",
                params![now, id],
            )
            .map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

pub fn list_assets(
    conn: &Connection,
    search: Option<&str>,
    active_tag: Option<&str>,
    limit: i64,
) -> Result<Vec<Asset>, String> {
    let mut sql = String::from(
        "SELECT a.id, a.asset_type, a.source_path, a.thumbnail_path, a.created_at, a.deleted_at, a.file_size, a.width, a.height, a.duration_ms \
         FROM assets a",
    );
    let mut conditions: Vec<String> = Vec::new();
    let mut binds: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();

    if let Some(tag) = active_tag.filter(|t| !t.is_empty()) {
        sql.push_str(
            " JOIN asset_tags at ON at.asset_id = a.id \
              JOIN tags t ON t.id = at.tag_id AND t.name = ?1 COLLATE NOCASE",
        );
        binds.push(Box::new(tag.to_string()));
    }
    if let Some(s) = search.filter(|s| !s.is_empty()) {
        let idx = binds.len() + 1;
        conditions.push(format!(
            "(a.source_path LIKE ?{idx} ESCAPE '\\' OR EXISTS (SELECT 1 FROM asset_tags at2 JOIN tags t2 ON t2.id = at2.tag_id WHERE at2.asset_id = a.id AND t2.name LIKE ?{idx} ESCAPE '\\'))"
        ));
        let pattern = format!("%{}%", s.replace('\\', "\\\\").replace('%', "\\%").replace('_', "\\_"));
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
        let (id, asset_type, source_path, thumbnail_path, created_at, deleted_at, file_size, width, height, duration_ms) =
            row.map_err(|e| e.to_string())?;
        let mut asset = Asset {
            id,
            asset_type,
            source_path: source_path.clone(),
            thumbnail_path,
            created_at,
            deleted: deleted_at.is_some(),
            file_size,
            width,
            height,
            duration_ms,
            tags: Vec::new(),
        };
        let mut tag_stmt = conn
            .prepare(
                "SELECT t.name FROM tags t JOIN asset_tags at ON at.tag_id = t.id WHERE at.asset_id = ?1 ORDER BY t.name",
            )
            .map_err(|e| e.to_string())?;
        let tag_iter = tag_stmt
            .query_map(params![id], |r| r.get::<_, String>(0))
            .map_err(|e| e.to_string())?;
        for t in tag_iter.flatten() {
            asset.tags.push(t);
        }
        assets.push(asset);
    }
    Ok(assets)
}

pub fn list_tags(conn: &Connection) -> Result<Vec<TagCount>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT t.name, COUNT(at.asset_id) AS cnt FROM tags t \
             LEFT JOIN asset_tags at ON at.tag_id = t.id \
             GROUP BY t.id \
             HAVING cnt > 0 \
             ORDER BY cnt DESC, t.name ASC",
        )
        .map_err(|e| e.to_string())?;
    let iter = stmt
        .query_map([], |r| {
            Ok(TagCount {
                name: r.get(0)?,
                count: r.get(1)?,
            })
        })
        .map_err(|e| e.to_string())?;
    Ok(iter.flatten().collect())
}
