use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};
use wabi::media_db;

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
    history: Vec<media_db::OcrItem>,
    colors: Vec<media_db::PickedColor>,
    monitor_fps: u32,
}

fn detect_monitor_fps() -> u32 {
    let out = Command::new("hyprctl")
        .args(["monitors", "-j"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_default();

    serde_json::from_str::<serde_json::Value>(&out)
        .ok()
        .and_then(|v| v.as_array().cloned())
        .and_then(|arr| arr.into_iter().next())
        .and_then(|first| first.get("refreshRate").and_then(|r| r.as_f64()))
        .map(|rate| rate.round() as u32)
        .filter(|n| *n > 0)
        .unwrap_or(60)
}

fn get_settings_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".config/quickshell/media_popup/settings.json")
}

fn load_settings() -> Settings {
    let path = get_settings_path();
    if let Ok(content) = fs::read_to_string(&path)
        && let Ok(settings) = serde_json::from_str(&content)
    {
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
            "add" => {
                if args.len() < 4 {
                    print_error("usage: add <type> <detail>");
                    return 1;
                }
                let conn = match media_db::open() {
                    Ok(c) => c,
                    Err(e) => {
                        print_error(&format!("db open: {e}"));
                        return 1;
                    }
                };
                if args[2] == "ocr" {
                    match media_db::add_ocr(&conn, &args[3]) {
                        Ok(id) => {
                            trigger_ping();
                            println!("{}", id);
                            return 0;
                        }
                        Err(e) => {
                            print_error(&e);
                            return 1;
                        }
                    }
                } else {
                    print_error("unknown add type");
                    return 1;
                }
            }
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
                        trigger_ping();
                        println!("{}", id);
                        return 0;
                    }
                    Err(e) => {
                        print_error(&e);
                        return 1;
                    }
                }
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
                trigger_ping();
                return 0;
            }
            "clear-assets" => {
                let conn = match media_db::open() {
                    Ok(c) => c,
                    Err(e) => {
                        print_error(&format!("db open: {e}"));
                        return 1;
                    }
                };
                if let Err(e) = media_db::clear_assets(&conn) {
                    print_error(&e);
                    return 1;
                }
                trigger_ping();
                return 0;
            }
            "clear-ocr" => {
                let conn = match media_db::open() {
                    Ok(c) => c,
                    Err(e) => {
                        print_error(&format!("db open: {e}"));
                        return 1;
                    }
                };
                if let Err(e) = media_db::clear_ocr(&conn) {
                    print_error(&e);
                    return 1;
                }
                trigger_ping();
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
                trigger_ping();
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
            "add-color" => {
                if args.len() < 3 {
                    print_error("usage: add-color <hex>");
                    return 1;
                }
                let conn = match media_db::open() {
                    Ok(c) => c,
                    Err(e) => {
                        print_error(&format!("db open: {e}"));
                        return 1;
                    }
                };
                match media_db::add_color(&conn, &args[2]) {
                    Ok(id) => {
                        trigger_ping();
                        println!("{id}");
                        return 0;
                    }
                    Err(e) => {
                        print_error(&e);
                        return 1;
                    }
                }
            }
            "remove-color" => {
                if args.len() < 3 {
                    print_error("usage: remove-color <id>");
                    return 1;
                }
                let id: i64 = match args[2].parse() {
                    Ok(v) => v,
                    Err(_) => {
                        print_error("invalid color id");
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
                if let Err(e) = media_db::remove_color(&conn, id) {
                    print_error(&e);
                    return 1;
                }
                trigger_ping();
                return 0;
            }
            "pick-color" => {
                return pick_color();
            }
            "clear-colors" => {
                let conn = match media_db::open() {
                    Ok(c) => c,
                    Err(e) => {
                        print_error(&format!("db open: {e}"));
                        return 1;
                    }
                };
                if let Err(e) = media_db::clear_colors(&conn) {
                    print_error(&e);
                    return 1;
                }
                trigger_ping();
                return 0;
            }
            "recording-status" => {
                let status = serde_json::json!({ "is_recording": is_wf_recorder_running() });
                if let Ok(json) = serde_json::to_string(&status) {
                    println!("{json}");
                }
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
    // Run filesystem check in a background thread to avoid blocking startup
    std::thread::spawn(|| {
        if let Ok(conn) = media_db::open() {
            let _ = media_db::check_deleted(&conn);
        }
    });
    let settings = load_settings();
    let is_recording = is_wf_recorder_running();

    let assets = media_db::list_assets(&conn, None, 50).unwrap_or_default();
    let history = media_db::list_ocr(&conn, 50).unwrap_or_default();
    let colors = media_db::list_colors(&conn, 24).unwrap_or_default();

    let status = MediaStatus {
        is_recording,
        screenshot_dir: settings.screenshot_dir,
        recording_dir: settings.recording_dir,
        assets,
        history,
        colors,
        monitor_fps: detect_monitor_fps(),
    };

    if let Ok(json) = serde_json::to_string(&status) {
        println!("{json}");
    }
    0
}

fn ping_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".config/quickshell/media_popup/ping.txt")
}

fn trigger_ping() {
    if let Some(parent) = ping_path().parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(ts) = SystemTime::now().duration_since(UNIX_EPOCH) {
        let _ = fs::write(
            ping_path(),
            format!("{}.{}\n", ts.as_secs(), ts.subsec_nanos()),
        );
    }
}

fn pick_color() -> i32 {
    let out = Command::new("hyprpicker").args(["-a", "-n"]).output();

    let out = match out {
        Ok(o) => o,
        Err(e) => {
            print_error(&format!("hyprpicker spawn: {e}"));
            return 1;
        }
    };

    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr);
        print_error(&format!(
            "hyprpicker rc={} stderr={}",
            out.status.code().unwrap_or(-1),
            stderr.trim()
        ));
        return 1;
    }

    let hex = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if !hex.starts_with('#') {
        print_error(&format!("no hex from hyprpicker: '{}'", hex));
        return 1;
    }

    let conn = match media_db::open() {
        Ok(c) => c,
        Err(e) => {
            print_error(&format!("db open: {e}"));
            return 1;
        }
    };

    match media_db::add_color(&conn, &hex) {
        Ok(id) => {
            trigger_ping();
            println!("{id}");
            0
        }
        Err(e) => {
            print_error(&e);
            1
        }
    }
}

fn main() {
    std::process::exit(run());
}
