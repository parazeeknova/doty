use wabi::media_db;
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

#[derive(Serialize, Deserialize, Clone, Debug)]
struct Settings {
    screenshot_dir: String,
    recording_dir: String,
}

impl Default for Settings {
    fn default() -> Self {
        let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        Self {
            screenshot_dir: format!("{home}/Pictures/Screenshots"),
            recording_dir: format!("{home}/Pictures/Recordings"),
        }
    }
}

#[derive(Serialize, Clone, Debug)]
struct MediaStatus {
    is_recording: bool,
    screenshot_dir: String,
    recording_dir: String,
    assets: Vec<media_db::Asset>,
    tags: Vec<media_db::TagCount>,
}

fn get_settings_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".config/quickshell/media_popup/settings.json")
}

fn load_settings() -> Settings {
    let path = get_settings_path();
    if let Ok(content) = fs::read_to_string(&path)
        && let Ok(settings) = serde_json::from_str(&content) {
            return settings;
        }
    Settings::default()
}

fn save_settings(settings: &Settings) {
    let path = get_settings_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(content) = serde_json::to_string_pretty(settings) {
        let _ = fs::write(path, content);
    }
}

fn is_wf_recorder_running() -> bool {
    let output = Command::new("pgrep").arg("-x").arg("wf-recorder").output();
    if let Ok(out) = output {
        out.status.success()
    } else {
        false
    }
}

fn print_error(msg: &str) {
    eprintln!("error: {msg}");
    if let Ok(json) = serde_json::to_string(&serde_json::json!({ "error": msg })) {
        println!("{json}");
    }
}

fn run() -> i32 {
    let args: Vec<String> = env::args().collect();

    if args.len() > 1 {
        match args[1].as_str() {
            "add-asset" => {
                if args.len() < 4 {
                    print_error("usage: add-asset <type> <path>");
                    return 1;
                }
                let conn = match media_db::open() {
                    Ok(c) => c,
                    Err(e) => {
                        print_error(&format!("db open: {e}"));
                        return 1;
                    }
                };
                match media_db::add_asset(&conn, &args[2], &args[3]) {
                    Ok(id) => {
                        println!("{}", id);
                        return 0;
                    }
                    Err(e) => {
                        print_error(&e);
                        return 1;
                    }
                }
            }
            "set-tags" => {
                if args.len() < 4 {
                    print_error("usage: set-tags <asset_id> <csv-tags>");
                    return 1;
                }
                let id: i64 = match args[2].parse() {
                    Ok(v) => v,
                    Err(_) => {
                        print_error("invalid asset id");
                        return 1;
                    }
                };
                let tags: Vec<String> = args[3]
                    .split(',')
                    .map(|s| s.to_string())
                    .collect();
                let conn = match media_db::open() {
                    Ok(c) => c,
                    Err(e) => {
                        print_error(&format!("db open: {e}"));
                        return 1;
                    }
                };
                if let Err(e) = media_db::set_tags(&conn, id, &tags) {
                    print_error(&e);
                    return 1;
                }
                return 0;
            }
            "remove-asset" => {
                if args.len() < 3 {
                    print_error("usage: remove-asset <asset_id>");
                    return 1;
                }
                let id: i64 = match args[2].parse() {
                    Ok(v) => v,
                    Err(_) => {
                        print_error("invalid asset id");
                        return 1;
                    }
                };
                let conn = match media_db::open() {
                    Ok(c) => c,
                    Err(e) => {
                        print_error(&format!("db open: {e}"));
                        return 1;
                    }
                };
                if let Err(e) = media_db::remove_asset(&conn, id) {
                    print_error(&e);
                    return 1;
                }
                return 0;
            }
            "clear-all" => {
                let conn = match media_db::open() {
                    Ok(c) => c,
                    Err(e) => {
                        print_error(&format!("db open: {e}"));
                        return 1;
                    }
                };
                if let Err(e) = media_db::clear_all(&conn) {
                    print_error(&e);
                    return 1;
                }
                return 0;
            }
            "set-screenshot-dir" => {
                if args.len() < 3 {
                    print_error("usage: set-screenshot-dir <path>");
                    return 1;
                }
                let mut settings = load_settings();
                settings.screenshot_dir = args[2].clone();
                save_settings(&settings);
                return 0;
            }
            "set-recording-dir" => {
                if args.len() < 3 {
                    print_error("usage: set-recording-dir <path>");
                    return 1;
                }
                let mut settings = load_settings();
                settings.recording_dir = args[2].clone();
                save_settings(&settings);
                return 0;
            }
            _ => {
                print_error(&format!("unknown subcommand: {}", args[1]));
                return 1;
            }
        }
    }

    let conn = match media_db::open() {
        Ok(c) => c,
        Err(e) => {
            print_error(&format!("db open: {e}"));
            return 1;
        }
    };
    let _ = media_db::check_deleted(&conn);
    let settings = load_settings();
    let is_recording = is_wf_recorder_running();

    let assets = media_db::list_assets(&conn, None, None, 50).unwrap_or_default();
    let tags = media_db::list_tags(&conn).unwrap_or_default();

    let status = MediaStatus {
        is_recording,
        screenshot_dir: settings.screenshot_dir,
        recording_dir: settings.recording_dir,
        assets,
        tags,
    };

    if let Ok(json) = serde_json::to_string(&status) {
        println!("{json}");
    }
    0
}

fn main() {
    std::process::exit(run());
}
