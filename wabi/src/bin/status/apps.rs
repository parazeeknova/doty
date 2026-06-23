use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};

#[derive(Serialize, Deserialize, Clone)]
struct AppInfo {
    name: String,
    exec: String,
    icon: String,
    #[serde(default)]
    count: u32,
}

#[derive(Serialize, Deserialize, Clone)]
struct WebHistoryItem {
    query: String,
    engine: String,
    url: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct FileHistoryItem {
    path: String,
    name: String,
    timestamp: i64,
}

#[derive(Serialize, Deserialize, Clone)]
struct FileIndexEntry {
    path: String,
    name: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct BookmarkItem {
    url: String,
    name: String,
}

fn url_encode(input: &str) -> String {
    let mut encoded = String::new();
    for byte in input.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                encoded.push(byte as char);
            }
            b' ' => {
                encoded.push('+');
            }
            _ => {
                encoded.push_str(&format!("%{:02X}", byte));
            }
        }
    }
    encoded
}

fn normalize_url(url: &str) -> String {
    let mut trimmed = url.trim().to_string();
    if !trimmed.contains("://") {
        trimmed = format!("https://{}", trimmed);
    }

    if let Some((scheme, rest)) = trimmed.split_once("://") {
        let scheme = scheme.to_lowercase();
        let (host, path_query) = match rest.split_once('/') {
            Some((h, p)) => (
                h.to_lowercase(),
                if p.is_empty() {
                    String::new()
                } else {
                    format!("/{}", p)
                },
            ),
            None => (rest.to_lowercase(), String::new()),
        };

        let mut path_clean = path_query;
        if path_clean.len() > 1 && path_clean.ends_with('/') {
            path_clean.pop();
        }

        format!("{}://{}{}", scheme, host, path_clean)
    } else {
        trimmed.to_lowercase()
    }
}

fn parse_web_search(query: &str) -> Option<WebHistoryItem> {
    let q = query.trim();
    if !q.starts_with('!') {
        return None;
    }

    let first_space = q.find(' ');
    let (trigger, search_text) = match first_space {
        None => (q.to_lowercase(), ""),
        Some(idx) => (q[..idx].to_lowercase(), q[idx + 1..].trim()),
    };

    let (engine_name, search_url, query_text) = if trigger == "!yt" || trigger == "!youtube" {
        (
            "youtube".to_string(),
            "https://www.youtube.com/results?search_query=".to_string(),
            search_text.to_string(),
        )
    } else if trigger == "!g" || trigger == "!google" {
        (
            "google".to_string(),
            "https://www.google.com/search?q=".to_string(),
            search_text.to_string(),
        )
    } else if trigger == "!gh" || trigger == "!github" {
        (
            "github".to_string(),
            "https://github.com/search?q=".to_string(),
            search_text.to_string(),
        )
    } else if trigger == "!w" || trigger == "!wiki" || trigger == "!wikipedia" {
        (
            "wikipedia".to_string(),
            "https://en.wikipedia.org/wiki/Special:Search?search=".to_string(),
            search_text.to_string(),
        )
    } else {
        let q_text = q[1..].to_string();
        (
            "duckduckgo".to_string(),
            "https://duckduckgo.com/?q=".to_string(),
            q_text,
        )
    };

    if query_text.is_empty() {
        return None;
    }

    let encoded_query = url_encode(&query_text);
    Some(WebHistoryItem {
        query: query_text,
        engine: engine_name,
        url: format!("{}{}", search_url, encoded_query),
    })
}

fn parse_desktop_file(path: &Path) -> Option<AppInfo> {
    let content = fs::read_to_string(path).ok()?;
    let mut name = None;
    let mut exec = None;
    let mut icon = None;
    let mut no_display = false;
    let mut in_desktop_entry = false;

    for line in content.lines() {
        let line = line.trim();
        if line.starts_with('[') && line.ends_with(']') {
            in_desktop_entry = line == "[Desktop Entry]";
            continue;
        }
        if !in_desktop_entry {
            continue;
        }

        if let Some(pos) = line.find('=') {
            let key = line[..pos].trim();
            let val = line[pos + 1..].trim();

            match key {
                "Name" => {
                    if name.is_none() {
                        name = Some(val.to_string());
                    }
                }
                "Exec" => {
                    if exec.is_none() {
                        let cleaned = val
                            .split_whitespace()
                            .filter(|arg| !arg.starts_with('%'))
                            .collect::<Vec<_>>()
                            .join(" ");
                        exec = Some(cleaned);
                    }
                }
                "Icon" => {
                    if icon.is_none() {
                        icon = Some(val.to_string());
                    }
                }
                "NoDisplay" if val.to_lowercase() == "true" => {
                    no_display = true;
                }
                _ => {}
            }
        }
    }

    if no_display {
        return None;
    }

    if let (Some(n), Some(e)) = (name, exec) {
        Some(AppInfo {
            name: n,
            exec: e,
            icon: icon.unwrap_or_default(),
            count: 0,
        })
    } else {
        None
    }
}

fn init_db() -> Result<Connection, rusqlite::Error> {
    let db_path = wabi::quickshell_dir()
        .join("apps_popup")
        .join("launcher.db");
    if let Some(parent) = db_path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let conn = Connection::open(&db_path)?;
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.pragma_update(None, "synchronous", "NORMAL")?;
    conn.pragma_update(None, "temp_store", "MEMORY")?;

    conn.execute_batch(
        r#"
        CREATE TABLE IF NOT EXISTS bookmarks (
            url TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS file_history (
            path TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS web_search_history (
            query TEXT COLLATE NOCASE NOT NULL,
            engine TEXT NOT NULL,
            url TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            PRIMARY KEY(query, engine)
        );
        CREATE TABLE IF NOT EXISTS app_usage (
            app_name TEXT PRIMARY KEY,
            count INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_file_history_timestamp ON file_history(timestamp DESC);
        CREATE INDEX IF NOT EXISTS idx_web_search_history_timestamp ON web_search_history(timestamp DESC);
        "#,
    )?;
    Ok(conn)
}

fn migrate_if_needed(conn: &Connection, cache_dir: &Path) {
    // 1. Migrate bookmarks
    let bookmarks_path = cache_dir.join("bookmarks.json");
    if bookmarks_path.exists() {
        let mut migrated = false;
        if let Ok(content) = fs::read_to_string(&bookmarks_path)
            && let Ok(list) = serde_json::from_str::<Vec<BookmarkItem>>(&content)
        {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs() as i64;
            let mut success = true;
            for (idx, item) in list.iter().enumerate() {
                let normalized = normalize_url(&item.url);
                if let Err(e) = conn.execute(
                    "INSERT OR IGNORE INTO bookmarks (url, name, created_at) VALUES (?1, ?2, ?3)",
                    params![normalized, item.name, now - idx as i64],
                ) {
                    eprintln!("Error migrating bookmark: {}", e);
                    success = false;
                }
            }
            if success {
                migrated = true;
            }
        }
        if migrated {
            let migrated_path = cache_dir.join("bookmarks.json.migrated");
            let _ = fs::rename(&bookmarks_path, &migrated_path);
        }
    }

    // 2. Migrate file history
    let file_history_path = cache_dir.join("file_history.json");
    if file_history_path.exists() {
        let mut migrated = false;
        if let Ok(content) = fs::read_to_string(&file_history_path)
            && let Ok(list) = serde_json::from_str::<Vec<FileHistoryItem>>(&content)
        {
            let mut success = true;
            for item in list {
                if let Err(e) = conn.execute(
                    "INSERT OR IGNORE INTO file_history (path, name, timestamp) VALUES (?1, ?2, ?3)",
                    params![item.path, item.name, item.timestamp],
                ) {
                    eprintln!("Error migrating file history: {}", e);
                    success = false;
                }
            }
            if success {
                migrated = true;
            }
        }
        if migrated {
            let migrated_path = cache_dir.join("file_history.json.migrated");
            let _ = fs::rename(&file_history_path, &migrated_path);
        }
    }

    // 3. Migrate web search history
    let web_history_path = cache_dir.join("web_search_history.json");
    if web_history_path.exists() {
        let mut migrated = false;
        if let Ok(content) = fs::read_to_string(&web_history_path)
            && let Ok(list) = serde_json::from_str::<Vec<WebHistoryItem>>(&content)
        {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs() as i64;
            let mut success = true;
            for (idx, item) in list.iter().enumerate() {
                if let Err(e) = conn.execute(
                    "INSERT OR IGNORE INTO web_search_history (query, engine, url, timestamp) VALUES (?1, ?2, ?3, ?4)",
                    params![item.query, item.engine, item.url, now - idx as i64],
                ) {
                    eprintln!("Error migrating web history: {}", e);
                    success = false;
                }
            }
            if success {
                migrated = true;
            }
        }
        if migrated {
            let migrated_path = cache_dir.join("web_search_history.json.migrated");
            let _ = fs::rename(&web_history_path, &migrated_path);
        }
    }

    // 4. Migrate app usage
    let usage_path = cache_dir.join("app_usage.json");
    if usage_path.exists() {
        let mut migrated = false;
        if let Ok(content) = fs::read_to_string(&usage_path)
            && let Ok(map) = serde_json::from_str::<HashMap<String, u32>>(&content)
        {
            let mut success = true;
            for (app_name, count) in map {
                if let Err(e) = conn.execute(
                    "INSERT OR REPLACE INTO app_usage (app_name, count) VALUES (?1, ?2)",
                    params![app_name, count],
                ) {
                    eprintln!("Error migrating app usage: {}", e);
                    success = false;
                }
            }
            if success {
                migrated = true;
            }
        }
        if migrated {
            let migrated_path = cache_dir.join("app_usage.json.migrated");
            let _ = fs::rename(&usage_path, &migrated_path);
        }
    }
}

fn get_bookmarks(conn: &Connection) -> Vec<BookmarkItem> {
    let mut stmt = match conn.prepare("SELECT url, name FROM bookmarks ORDER BY created_at DESC") {
        Ok(s) => s,
        Err(_) => return Vec::new(),
    };
    let rows = stmt.query_map([], |row| {
        Ok(BookmarkItem {
            url: row.get(0)?,
            name: row.get(1)?,
        })
    });
    match rows {
        Ok(r) => r.filter_map(Result::ok).collect(),
        Err(_) => Vec::new(),
    }
}

fn add_bookmark(conn: &Connection, url: &str) -> Result<(), rusqlite::Error> {
    let normalized_url = normalize_url(url);
    let name = normalized_url
        .trim_start_matches("https://")
        .trim_start_matches("http://")
        .trim_start_matches("www.")
        .split('/')
        .next()
        .unwrap_or(&normalized_url)
        .to_string();

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;

    conn.execute(
        "INSERT OR REPLACE INTO bookmarks (url, name, created_at) VALUES (?1, ?2, ?3)",
        params![normalized_url, name, now],
    )?;
    Ok(())
}

fn delete_bookmark(conn: &Connection, url: &str) -> Result<(), rusqlite::Error> {
    let normalized_url = normalize_url(url);
    conn.execute(
        "DELETE FROM bookmarks WHERE url = ?1",
        params![normalized_url],
    )?;
    Ok(())
}

fn clear_bookmarks(conn: &Connection) -> Result<(), rusqlite::Error> {
    conn.execute("DELETE FROM bookmarks", [])?;
    Ok(())
}

fn get_file_history(conn: &Connection) -> Vec<FileHistoryItem> {
    let mut stmt = match conn
        .prepare("SELECT path, name, timestamp FROM file_history ORDER BY timestamp DESC LIMIT 30")
    {
        Ok(s) => s,
        Err(_) => return Vec::new(),
    };
    let rows = stmt.query_map([], |row| {
        Ok(FileHistoryItem {
            path: row.get(0)?,
            name: row.get(1)?,
            timestamp: row.get(2)?,
        })
    });
    match rows {
        Ok(r) => r.filter_map(Result::ok).collect(),
        Err(_) => Vec::new(),
    }
}

fn add_file_history(conn: &Connection, file_path: &str) -> Result<(), rusqlite::Error> {
    let name = Path::new(file_path)
        .file_name()
        .and_then(|f| f.to_str())
        .unwrap_or(file_path)
        .to_string();

    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;

    conn.execute(
        "INSERT OR REPLACE INTO file_history (path, name, timestamp) VALUES (?1, ?2, ?3)",
        params![file_path, name, timestamp],
    )?;
    Ok(())
}

fn clear_file_history(conn: &Connection) -> Result<(), rusqlite::Error> {
    conn.execute("DELETE FROM file_history", [])?;
    Ok(())
}

fn get_web_history(conn: &Connection) -> Vec<WebHistoryItem> {
    let mut stmt = match conn.prepare(
        "SELECT query, engine, url FROM web_search_history ORDER BY timestamp DESC LIMIT 20",
    ) {
        Ok(s) => s,
        Err(_) => return Vec::new(),
    };
    let rows = stmt.query_map([], |row| {
        Ok(WebHistoryItem {
            query: row.get(0)?,
            engine: row.get(1)?,
            url: row.get(2)?,
        })
    });
    match rows {
        Ok(r) => r.filter_map(Result::ok).collect(),
        Err(_) => Vec::new(),
    }
}

fn add_web_history(conn: &Connection, item: &WebHistoryItem) -> Result<(), rusqlite::Error> {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;

    conn.execute(
        "INSERT OR REPLACE INTO web_search_history (query, engine, url, timestamp) VALUES (?1, ?2, ?3, ?4)",
        params![item.query, item.engine, item.url, timestamp],
    )?;
    Ok(())
}

fn clear_web_history(conn: &Connection) -> Result<(), rusqlite::Error> {
    conn.execute("DELETE FROM web_search_history", [])?;
    Ok(())
}

fn get_usage_map(conn: &Connection) -> HashMap<String, u32> {
    let mut stmt = match conn.prepare("SELECT app_name, count FROM app_usage") {
        Ok(s) => s,
        Err(_) => return HashMap::new(),
    };
    let rows = stmt.query_map([], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, u32>(1)?))
    });
    match rows {
        Ok(r) => r.filter_map(Result::ok).collect(),
        Err(_) => HashMap::new(),
    }
}

fn increment_app_usage(conn: &Connection, app_name: &str) -> Result<(), rusqlite::Error> {
    conn.execute(
        "INSERT INTO app_usage (app_name, count) VALUES (?1, 1) ON CONFLICT(app_name) DO UPDATE SET count = count + 1",
        params![app_name],
    )?;
    Ok(())
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let home = std::env::var("HOME").unwrap_or_default();
    let cache_dir = wabi::cache_dir();

    // Initialize database
    let conn = match init_db() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Error initializing SQLite database: {}", e);
            // Print empty default JSON response to stdout
            let empty_res = serde_json::json!({
                "most_used": [],
                "all_apps": [],
                "web_history": [],
                "file_history": [],
                "bookmarks": []
            });
            let _ = serde_json::to_writer(std::io::stdout(), &empty_res);
            return;
        }
    };

    // Automatically migrate old JSON files
    migrate_if_needed(&conn, &cache_dir);

    let action = args.get(1).map(String::as_str);

    match action {
        Some("--clear-history") => {
            if let Err(e) = clear_web_history(&conn) {
                eprintln!("Error clearing web search history: {}", e);
            }
        }
        Some("--clear-file-history") => {
            if let Err(e) = clear_file_history(&conn) {
                eprintln!("Error clearing file history: {}", e);
            }
        }
        Some("--add-bookmark") => {
            if let Some(url) = args.get(2) {
                let res = add_bookmark(&conn, url);
                if let Err(e) = res {
                    eprintln!("Error adding bookmark: {}", e);
                }
            }
        }
        Some("--delete-bookmark") => {
            if let Some(url) = args.get(2) {
                let res = delete_bookmark(&conn, url);
                if let Err(e) = res {
                    eprintln!("Error deleting bookmark: {}", e);
                }
            }
        }
        Some("--clear-bookmarks") => {
            if let Err(e) = clear_bookmarks(&conn) {
                eprintln!("Error clearing bookmarks: {}", e);
            }
        }
        Some("--index-files") => {
            let index_path = cache_dir.join("file_index.json");
            let _ = fs::create_dir_all(&cache_dir);

            let output = Command::new("fd")
                .args([
                    "--type",
                    "f",
                    "--hidden",
                    "--exclude",
                    ".git",
                    "--exclude",
                    "node_modules",
                    "--exclude",
                    ".cache",
                    "--exclude",
                    "target",
                    "--max-depth",
                    "8",
                ])
                .current_dir(&home)
                .output();

            if let Ok(out) = output {
                let mut entries: Vec<FileIndexEntry> = Vec::new();
                for line in String::from_utf8_lossy(&out.stdout).lines() {
                    let display_path = format!("~/{}", line);
                    let name = Path::new(line)
                        .file_name()
                        .and_then(|f| f.to_str())
                        .unwrap_or(line)
                        .to_string();
                    entries.push(FileIndexEntry {
                        path: display_path,
                        name,
                    });
                }
                if let Ok(serialized) = serde_json::to_string(&entries) {
                    let _ = fs::write(&index_path, serialized);
                }
                println!("{}", serde_json::json!({"indexed": entries.len()}));
            }
        }
        Some("--search-files") => {
            if let Some(query) = args.get(2) {
                let index_path = cache_dir.join("file_index.json");

                if !index_path.exists() {
                    println!("[]");
                    return;
                }

                if let Ok(content) = fs::read_to_string(&index_path)
                    && let Ok(entries) = serde_json::from_str::<Vec<FileIndexEntry>>(&content)
                {
                    let mut fzf = Command::new("fzf")
                        .args(["-f", query])
                        .stdin(Stdio::piped())
                        .stdout(Stdio::piped())
                        .spawn()
                        .ok();

                    if let Some(ref mut stdin) = fzf.as_mut().and_then(|f| f.stdin.as_mut()) {
                        for entry in &entries {
                            let _ = writeln!(stdin, "{}", entry.path);
                        }
                    }

                    if let Some(child) = fzf
                        && let Ok(output) = child.wait_with_output()
                    {
                        let results: Vec<FileIndexEntry> = String::from_utf8_lossy(&output.stdout)
                            .lines()
                            .filter_map(|line| entries.iter().find(|e| e.path == line).cloned())
                            .take(50)
                            .collect();
                        let _ = serde_json::to_writer(std::io::stdout(), &results);
                        return;
                    }
                }
            }
            println!("[]");
        }
        Some("--open-file") => {
            if let Some(file_path) = args.get(2) {
                if let Err(e) = add_file_history(&conn, file_path) {
                    eprintln!("Error adding file to history: {}", e);
                }

                let open_path = if let Some(stripped) = file_path.strip_prefix("~/") {
                    format!("{}/{}", home, stripped)
                } else {
                    file_path.to_string()
                };
                let _ = Command::new("thunar").arg(&open_path).status();
            }
        }
        Some("--file-history") => {
            let history = get_file_history(&conn);
            let _ = serde_json::to_writer(std::io::stdout(), &history);
        }
        Some("--launch") => {
            if let Some(app_name) = args.get(2) {
                let res = increment_app_usage(&conn, app_name);
                if let Err(e) = res {
                    eprintln!("Error incrementing app usage: {}", e);
                }
            }
        }
        Some("--web-search") => {
            if let Some(item) = args.get(2).and_then(|q| parse_web_search(q)) {
                let res = add_web_history(&conn, &item);
                if let Err(e) = res {
                    eprintln!("Error saving web search history: {}", e);
                }
                // Open in browser
                let _ = Command::new("xdg-open").arg(&item.url).status();

                // Switch to workspace 1
                let _ = Command::new("hyprctl")
                    .args(["dispatch", "hl.dsp.focus({workspace=1})"])
                    .status();
            }
        }
        Some("--web-search-item") => {
            if let (Some(query), Some(engine), Some(url)) = (args.get(2), args.get(3), args.get(4))
            {
                let item = WebHistoryItem {
                    query: query.to_string(),
                    engine: engine.to_string(),
                    url: url.to_string(),
                };
                if !item.query.trim().is_empty() && !item.url.trim().is_empty() {
                    let res = add_web_history(&conn, &item);
                    if let Err(e) = res {
                        eprintln!("Error saving web search history: {}", e);
                    }
                    let _ = Command::new("xdg-open").arg(&item.url).status();
                    let _ = Command::new("hyprctl")
                        .args(["dispatch", "hl.dsp.focus({workspace=1})"])
                        .status();
                }
            }
        }
        _ => {
            // Load usage map
            let usage_map = get_usage_map(&conn);

            let mut apps: HashMap<String, AppInfo> = HashMap::new();

            let paths = [
                "/usr/share/applications".to_string(),
                format!("{}/.local/share/applications", home),
                "/var/lib/flatpak/exports/share/applications".to_string(),
                format!("{}/.local/share/flatpak/exports/share/applications", home),
            ];

            for dir_path in &paths {
                let path = Path::new(dir_path);
                if !path.exists() {
                    continue;
                }
                if let Ok(entries) = fs::read_dir(path) {
                    for entry in entries.flatten() {
                        let p = entry.path();
                        if p.extension().is_some_and(|ext| ext == "desktop") {
                            let file_name_opt = p.file_name().and_then(|f| f.to_str());
                            if let Some(file_name) = file_name_opt {
                                let app_info_opt = parse_desktop_file(&p);
                                if let Some(mut app_info) = app_info_opt {
                                    if let Some(&count) = usage_map.get(&app_info.name) {
                                        app_info.count = count;
                                    }
                                    apps.insert(file_name.to_string(), app_info);
                                }
                            }
                        }
                    }
                }
            }

            let mut all_apps: Vec<AppInfo> = apps.into_values().collect();

            // Sort all apps alphabetically
            all_apps.sort_by_key(|a| a.name.to_lowercase());

            // Get most used apps (count > 0), sorted descending by count, limited to 5
            let mut most_used: Vec<AppInfo> = all_apps
                .iter()
                .filter(|app| app.count > 0)
                .cloned()
                .collect();
            most_used.sort_by(|a, b| {
                b.count
                    .cmp(&a.count)
                    .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
            });
            most_used.truncate(5);

            // Load histories and bookmarks
            let web_history = get_web_history(&conn);
            let file_history = get_file_history(&conn);
            let bookmarks = get_bookmarks(&conn);

            #[derive(Serialize)]
            struct Response {
                most_used: Vec<AppInfo>,
                all_apps: Vec<AppInfo>,
                web_history: Vec<WebHistoryItem>,
                file_history: Vec<FileHistoryItem>,
                bookmarks: Vec<BookmarkItem>,
            }

            let _ = serde_json::to_writer(
                std::io::stdout(),
                &Response {
                    most_used,
                    all_apps,
                    web_history,
                    file_history,
                    bookmarks,
                },
            );
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_url() {
        assert_eq!(normalize_url("example.com"), "https://example.com");
        assert_eq!(normalize_url("example.com/"), "https://example.com");
        assert_eq!(
            normalize_url("https://Mail.Google.com/Mail/u/0/"),
            "https://mail.google.com/Mail/u/0"
        );
        assert_eq!(normalize_url("http://foo.bar/"), "http://foo.bar");
    }

    #[test]
    fn test_parse_web_search() {
        let res = parse_web_search("!g rust");
        assert!(res.is_some());
        let item = res.unwrap();
        assert_eq!(item.engine, "google");
        assert_eq!(item.query, "rust");
        assert_eq!(item.url, "https://www.google.com/search?q=rust");
    }
}
