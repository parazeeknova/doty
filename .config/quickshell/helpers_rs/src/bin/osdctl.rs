use helpers_rs::{quickshell_dir, run_cmd};
use serde::Serialize;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

#[derive(Serialize)]
struct State {
    visible: bool,
    text: String,
    kind: String,
    timeout_ms: u64,
}

fn state_file() -> PathBuf {
    quickshell_dir().join("osd/state.json")
}

fn write_state_file(state: &State) {
    let path = state_file();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json_str) = serde_json::to_string(state) {
        let tmp_path = path.with_extension("json.tmp");
        if fs::write(&tmp_path, json_str).is_ok() {
            let _ = fs::rename(&tmp_path, path);
        }
    }
}

fn write_state(text: &str, kind: &str, timeout_ms: u64) {
    let state = State {
        visible: true,
        text: text.to_string(),
        kind: kind.to_string(),
        timeout_ms,
    };
    write_state_file(&state);
}

fn clear_state() {
    let state = State {
        visible: false,
        text: "".to_string(),
        kind: "info".to_string(),
        timeout_ms: 1200,
    };
    write_state_file(&state);
}

fn brightness_value() -> String {
    let out = run_cmd("brightnessctl", &["-m"]).unwrap_or_default();
    let parts: Vec<&str> = out.split(',').collect();
    if parts.len() >= 4 {
        parts[3].trim().to_string()
    } else {
        "0%".to_string()
    }
}

fn set_brightness(direction: &str) {
    if direction == "up" {
        let _ = Command::new("brightnessctl")
            .args(["-e4", "-n2", "set", "5%+"])
            .output();
    } else {
        let _ = Command::new("brightnessctl")
            .args(["-e4", "-n2", "set", "5%-"])
            .output();
    }
    write_state(&format!("brightness {}", brightness_value()), "info", 1200);
}

fn find_kbd_backlight_device() -> String {
    if let Ok(entries) = fs::read_dir("/sys/class/leds") {
        for entry in entries.flatten() {
            if let Some(name) = entry.file_name().to_str()
                && name.ends_with("kbd_backlight")
            {
                return name.to_string();
            }
        }
    }
    "asus::kbd_backlight".to_string()
}

fn kbd_brightness_value() -> String {
    let dev = find_kbd_backlight_device();
    let out = run_cmd("brightnessctl", &["-d", &dev, "-m"]).unwrap_or_default();
    let parts: Vec<&str> = out.split(',').collect();
    if parts.len() >= 4 {
        parts[3].trim().to_string()
    } else {
        "0%".to_string()
    }
}

fn set_kbd_brightness(direction: &str) {
    let dev = find_kbd_backlight_device();
    if direction == "up" {
        let _ = Command::new("brightnessctl")
            .args(["-d", &dev, "set", "1+"])
            .output();
    } else {
        let _ = Command::new("brightnessctl")
            .args(["-d", &dev, "set", "1-"])
            .output();
    }
    write_state(
        &format!("kbd brightness {}", kbd_brightness_value()),
        "info",
        1200,
    );
}

fn sink_volume() -> (i64, bool) {
    let out = run_cmd("wpctl", &["get-volume", "@DEFAULT_AUDIO_SINK@"]).unwrap_or_default();
    let muted = out.to_uppercase().contains("MUTED");
    let clean = out.replace(":", "");
    let parts: Vec<&str> = clean.split_whitespace().collect();
    let mut val = 0.0;
    if parts.len() >= 2
        && let Ok(parsed) = parts[1].parse::<f64>()
    {
        val = parsed;
    }
    ((val * 100.0).round() as i64, muted)
}

fn source_volume() -> (i64, bool) {
    let out = run_cmd("wpctl", &["get-volume", "@DEFAULT_AUDIO_SOURCE@"]).unwrap_or_default();
    let muted = out.to_uppercase().contains("MUTED");
    let clean = out.replace(":", "");
    let parts: Vec<&str> = clean.split_whitespace().collect();
    let mut val = 0.0;
    if parts.len() >= 2
        && let Ok(parsed) = parts[1].parse::<f64>()
    {
        val = parsed;
    }
    ((val * 100.0).round() as i64, muted)
}

fn set_volume(action: &str) {
    match action {
        "up" => {
            let _ = Command::new("wpctl")
                .args(["set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "5%+"])
                .output();
            let (percent, _) = sink_volume();
            write_state(&format!("volume {}%", percent), "info", 1200);
        }
        "down" => {
            let _ = Command::new("wpctl")
                .args(["set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"])
                .output();
            let (percent, _) = sink_volume();
            write_state(&format!("volume {}%", percent), "info", 1200);
        }
        "mute" => {
            let _ = Command::new("wpctl")
                .args(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                .output();
            let (percent, muted) = sink_volume();
            if muted {
                write_state("volume muted", "warn", 1200);
            } else {
                write_state(&format!("volume {}%", percent), "info", 1200);
            }
        }
        "mic-mute" => {
            let _ = Command::new("wpctl")
                .args(["set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
                .output();
            let (percent, muted) = source_volume();
            if muted {
                write_state("mic muted", "warn", 1200);
            } else {
                write_state(&format!("mic {}%", percent), "info", 1200);
            }
        }
        _ => {}
    }
}

fn get_caps_state() -> bool {
    std::thread::sleep(std::time::Duration::from_millis(100));

    if let Ok(out) = Command::new("hyprctl").args(["devices", "-j"]).output() {
        let out_str = String::from_utf8_lossy(&out.stdout);
        if let Ok(devices) = serde_json::from_str::<serde_json::Value>(&out_str)
            && let Some(keyboards) = devices.get("keyboards").and_then(|v| v.as_array())
        {
            for kb in keyboards {
                if kb
                    .get("capsLock")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false)
                {
                    return true;
                }
            }
        }
    }

    if let Ok(entries) = fs::read_dir("/sys/class/leds") {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(name) = path.file_name().and_then(|n| n.to_str())
                && name.ends_with("::capslock")
                && let Ok(val) = fs::read_to_string(path.join("brightness"))
                && val.trim() != "0"
            {
                return true;
            }
        }
    }
    false
}

fn set_caps(state: &str) {
    let enabled = if state == "toggle" {
        get_caps_state()
    } else {
        state == "on"
    };
    write_state(
        &format!("caps {}", if enabled { "on" } else { "off" }),
        if enabled { "good" } else { "info" },
        1200,
    );
}

fn show_text(args: &[String]) {
    if args.is_empty() {
        return;
    }
    let mut text_parts = args.to_vec();
    let mut timeout = 1200;
    let mut kind = "info".to_string();

    if text_parts.len() >= 2
        && let Ok(parsed) = text_parts.last().unwrap().parse::<u64>()
    {
        timeout = parsed;
        text_parts.pop();
    }
    if text_parts.len() >= 2 {
        let last = text_parts.last().unwrap();
        if last == "info" || last == "good" || last == "warn" || last == "bad" {
            kind = last.to_string();
            text_parts.pop();
        }
    }
    write_state(&text_parts.join(" "), &kind, timeout);
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        return;
    }
    let command = &args[1];
    match command.as_str() {
        "brightness" if args.len() >= 3 => {
            set_brightness(&args[2]);
        }
        "kbdbrightness" if args.len() >= 3 => {
            set_kbd_brightness(&args[2]);
        }
        "volume" if args.len() >= 3 => {
            set_volume(&args[2]);
        }
        "caps" if args.len() >= 3 => {
            set_caps(&args[2]);
        }
        "show" => {
            show_text(&args[2..]);
        }
        "clear" => {
            clear_state();
        }
        _ => {}
    }
}
