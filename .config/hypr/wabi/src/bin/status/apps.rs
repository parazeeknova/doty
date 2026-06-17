use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

#[derive(Serialize, Deserialize, Clone)]
struct AppInfo {
    name: String,
    exec: String,
    icon: String,
    #[serde(default)]
    count: u32,
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
                        // Clean exec string from arguments like %u, %F, %U
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

    let mut apps: HashMap<String, AppInfo> = HashMap::new();

    let home = std::env::var("HOME").unwrap_or_default();
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

    #[derive(Serialize)]
    struct Response {
        most_used: Vec<AppInfo>,
        all_apps: Vec<AppInfo>,
    }

    let _ = serde_json::to_writer(
        std::io::stdout(),
        &Response {
            most_used,
            all_apps,
        },
    );
}
