use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::process::Command;

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
        let q_text = if first_space.is_none() {
            q[1..].to_string()
        } else {
            q[1..].to_string()
        };
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
                "NoDisplay" => {
                    if val.to_lowercase() == "true" {
                        no_display = true;
                    }
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

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let home = std::env::var("HOME").unwrap_or_default();
    let cache_dir = Path::new(&home).join(".cache/quickshell");
    let usage_path = cache_dir.join("app_usage.json");

    // Load usage map
    let mut usage_map: HashMap<String, u32> = HashMap::new();
    if usage_path.exists() {
        if let Ok(content) = fs::read_to_string(&usage_path) {
            if let Ok(map) = serde_json::from_str::<HashMap<String, u32>>(&content) {
                usage_map = map;
            }
        }
    }

    // Handle --launch <app_name>
    if args.len() > 2 && args[1] == "--launch" {
        let app_name = &args[2];
        let count = usage_map.entry(app_name.clone()).or_insert(0);
        *count += 1;

        let _ = fs::create_dir_all(&cache_dir);
        if let Ok(serialized) = serde_json::to_string(&usage_map) {
            let _ = fs::write(&usage_path, serialized);
        }
        return;
    }

    // Handle --web-search <query>
    if args.len() > 2 && args[1] == "--web-search" {
        let query = &args[2];
        if let Some(item) = parse_web_search(query) {
            let history_path = cache_dir.join("web_search_history.json");
            let mut history: Vec<WebHistoryItem> = Vec::new();
            if history_path.exists() {
                if let Ok(content) = fs::read_to_string(&history_path) {
                    if let Ok(list) = serde_json::from_str::<Vec<WebHistoryItem>>(&content) {
                        history = list;
                    }
                }
            }

            // De-duplicate
            history.retain(|x| {
                !(x.query.to_lowercase() == item.query.to_lowercase() && x.engine == item.engine)
            });
            // Insert at front
            history.insert(0, item.clone());
            // Limit to 20
            history.truncate(20);

            // Save history
            let _ = fs::create_dir_all(&cache_dir);
            if let Ok(serialized) = serde_json::to_string(&history) {
                let _ = fs::write(&history_path, serialized);
            }

            // Open in browser
            let _ = Command::new("xdg-open").arg(&item.url).status();

            // Switch to workspace 1
            let _ = Command::new("hyprctl")
                .args(["dispatch", "hl.dsp.focus({workspace=1})"])
                .status();
        }
        return;
    }

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
                if p.extension().map_or(false, |ext| ext == "desktop") {
                    if let Some(file_name) = p.file_name().and_then(|f| f.to_str()) {
                        if let Some(mut app_info) = parse_desktop_file(&p) {
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
    all_apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));

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

    // Load web history
    let history_path = cache_dir.join("web_search_history.json");
    let mut web_history: Vec<WebHistoryItem> = Vec::new();
    if history_path.exists() {
        if let Ok(content) = fs::read_to_string(&history_path) {
            if let Ok(list) = serde_json::from_str::<Vec<WebHistoryItem>>(&content) {
                web_history = list;
            }
        }
    }

    #[derive(Serialize)]
    struct Response {
        most_used: Vec<AppInfo>,
        all_apps: Vec<AppInfo>,
        web_history: Vec<WebHistoryItem>,
    }

    let _ = serde_json::to_writer(
        std::io::stdout(),
        &Response {
            most_used,
            all_apps,
            web_history,
        },
    );
}
