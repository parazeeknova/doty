use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::time::SystemTime;

#[derive(Serialize, Deserialize, Clone, Debug)]
struct HistoryEntry {
    id: u64,
    #[serde(rename = "type")]
    entry_type: String,
    timestamp: String,
    detail: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct Settings {
    screenshot_dir: String,
    recording_dir: String,
}

impl Default for Settings {
    fn default() -> Self {
        let home = env::var("HOME").unwrap_or_else(|_| "/home/parazeeknova".to_string());
        Self {
            screenshot_dir: format!("{}/Pictures/Screenshots", home),
            recording_dir: format!("{}/Pictures/Recordings", home),
        }
    }
}

#[derive(Serialize, Clone, Debug)]
struct MediaStatus {
    is_recording: bool,
    screenshot_dir: String,
    recording_dir: String,
    history: Vec<HistoryEntry>,
}

fn get_settings_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/parazeeknova".to_string());
    PathBuf::from(home).join(".config/quickshell/media_popup/settings.json")
}

fn get_history_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/parazeeknova".to_string());
    PathBuf::from(home).join(".cache/quickshell_media_history.json")
}

fn load_settings() -> Settings {
    let path = get_settings_path();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(settings) = serde_json::from_str(&content) {
            return settings;
        }
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

fn load_history() -> Vec<HistoryEntry> {
    let path = get_history_path();
    let mut history: Vec<HistoryEntry> = if let Ok(content) = fs::read_to_string(&path) {
        serde_json::from_str(&content).unwrap_or_default()
    } else {
        Vec::new()
    };
    
    let mut changed = false;
    history.retain(|entry| {
        if entry.detail.starts_with('/') {
            let exists = std::path::Path::new(&entry.detail).exists();
            if !exists {
                changed = true;
            }
            exists
        } else {
            true
        }
    });
    
    if changed {
        save_history(&history);
    }
    
    history
}

fn save_history(history: &[HistoryEntry]) {
    let path = get_history_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(content) = serde_json::to_string_pretty(history) {
        let _ = fs::write(path, content);
    }
}

fn is_wf_recorder_running() -> bool {
    let output = Command::new("pgrep")
        .arg("-x")
        .arg("wf-recorder")
        .output();
    if let Ok(out) = output {
        out.status.success()
    } else {
        false
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let mut updated = false;
    
    if args.len() > 1 {
        let subcommand = &args[1];
        match subcommand.as_str() {
            "add" => {
                if args.len() >= 4 {
                    let entry_type = &args[2];
                    let detail = &args[3];
                    let mut history = load_history();
                    
                    let timestamp = Command::new("date")
                        .arg("+%H:%M:%S")
                        .output()
                        .ok()
                        .and_then(|o| String::from_utf8(o.stdout).ok())
                        .unwrap_or_else(|| "00:00:00".to_string())
                        .trim()
                        .to_string();
                    
                    let id = SystemTime::now()
                        .duration_since(SystemTime::UNIX_EPOCH)
                        .map(|d| d.as_millis() as u64)
                        .unwrap_or(0);
                        
                    let entry = HistoryEntry {
                        id,
                        entry_type: entry_type.clone(),
                        timestamp,
                        detail: detail.clone(),
                    };
                    history.insert(0, entry);
                    if history.len() > 20 {
                        history.truncate(20);
                    }
                    save_history(&history);
                    updated = true;
                }
            }
            "set-screenshot-dir" => {
                if args.len() >= 3 {
                    let mut settings = load_settings();
                    settings.screenshot_dir = args[2].clone();
                    save_settings(&settings);
                    updated = true;
                }
            }
            "set-recording-dir" => {
                if args.len() >= 3 {
                    let mut settings = load_settings();
                    settings.recording_dir = args[2].clone();
                    save_settings(&settings);
                    updated = true;
                }
            }
            "clear-history" => {
                save_history(&[]);
                updated = true;
            }
            _ => {}
        }
    }
    
    // Only output status on stdout if not doing a silent subcommand,
    // or if we just want to retrieve the new state.
    // Actually, printing the status unconditionally makes it easy for Quickshell
    // to execute a command and instantly receive the updated JSON payload!
    let settings = load_settings();
    let history = load_history();
    let is_recording = is_wf_recorder_running();
    
    let status = MediaStatus {
        is_recording,
        screenshot_dir: settings.screenshot_dir,
        recording_dir: settings.recording_dir,
        history,
    };
    
    if let Ok(json) = serde_json::to_string(&status) {
        println!("{}", json);
    }
}
