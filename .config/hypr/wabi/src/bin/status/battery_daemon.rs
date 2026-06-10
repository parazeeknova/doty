use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::process::Command;

#[derive(Serialize, Deserialize, Debug, Clone)]
struct Settings {
    #[serde(default = "default_true")]
    automation_enabled: bool,
    #[serde(default = "default_threshold")]
    low_battery_threshold: i32,
    #[serde(default = "default_low_profile")]
    low_profile: String,
    #[serde(default = "default_bat_profile")]
    bat_profile: String,
    #[serde(default = "default_ac_profile")]
    ac_profile: String,
    #[serde(default = "default_bat_screen")]
    bat_screen_brightness: i32,
    #[serde(default = "default_bat_kbd")]
    bat_kbd_brightness: i32,
    #[serde(default = "default_ac_screen")]
    ac_screen_brightness: i32,
    #[serde(default = "default_ac_kbd")]
    ac_kbd_brightness: i32,
    #[serde(default = "default_low_screen")]
    low_screen_brightness: i32,
    #[serde(default = "default_low_kbd")]
    low_kbd_brightness: i32,
}

fn default_true() -> bool { true }
fn default_threshold() -> i32 { 25 }
fn default_low_profile() -> String { "Quiet".to_string() }
fn default_bat_profile() -> String { "Balanced".to_string() }
fn default_ac_profile() -> String { "Performance".to_string() }
fn default_bat_screen() -> i32 { 70 }
fn default_bat_kbd() -> i32 { 33 }
fn default_ac_screen() -> i32 { 100 }
fn default_ac_kbd() -> i32 { 90 }
fn default_low_screen() -> i32 { 30 }
fn default_low_kbd() -> i32 { 0 }

fn load_settings(path: &Path) -> Settings {
    let default_settings = Settings {
        automation_enabled: true,
        low_battery_threshold: 25,
        low_profile: "Quiet".to_string(),
        bat_profile: "Balanced".to_string(),
        ac_profile: "Performance".to_string(),
        bat_screen_brightness: 70,
        bat_kbd_brightness: 33,
        ac_screen_brightness: 100,
        ac_kbd_brightness: 90,
        low_screen_brightness: 30,
        low_kbd_brightness: 0,
    };

    if !path.exists() {
        if let Some(parent) = path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if let Ok(json_str) = serde_json::to_string_pretty(&default_settings) {
            let _ = fs::write(path, json_str);
        }
        return default_settings;
    }

    match fs::read_to_string(path) {
        Ok(content) => match serde_json::from_str::<Settings>(&content) {
            Ok(settings) => settings,
            Err(_) => default_settings,
        },
        Err(_) => default_settings,
    }
}

fn notify(title: &str, message: &str, icon: &str) {
    let home = std::env::var("HOME").unwrap_or_default();
    let osdctl_path = Path::new(&home).join(".config/quickshell/osd/bin/osdctl");
    if osdctl_path.exists() {
        let _ = Command::new(&osdctl_path)
            .args(["show", &format!("{}: {}", title, message), "good", "2000"])
            .status();
    }
    let _ = Command::new("notify-send")
        .args([title, message, "-i", icon, "-t", "3000"])
        .status();
}

fn set_profile(profile: &str) {
    let _ = Command::new("asusctl")
        .args(["profile", "set", profile])
        .status();
}

fn set_brightness(percent: i32) {
    let _ = Command::new("brightnessctl")
        .args(["set", &format!("{}%", percent)])
        .status();
}

fn set_keyboard_brightness(percent: i32) {
    if let Some(dev) = wabi::find_kbd_backlight_device() {
        let max_path = Path::new("/sys/class/leds").join(&dev).join("max_brightness");
        if let Ok(content) = fs::read_to_string(&max_path)
            && let Ok(max_val) = content.trim().parse::<f64>() {
                let val = ((percent as f64 / 100.0) * max_val).round() as i32;
                let _ = Command::new("brightnessctl")
                    .args(["-d", &dev, "set", &val.to_string()])
                    .status();
            }
    }
}

fn main() {
    let Some(bat_dir) = wabi::find_battery_dir() else {
        eprintln!("No battery supply found. Exiting daemon.");
        std::process::exit(0);
    };

    let home = std::env::var("HOME").unwrap_or_default();
    let settings_path = Path::new(&home).join(".config/quickshell/battery_popup/settings.json");

    let mut last_status: Option<String> = None;
    let mut last_capacity: Option<i32> = None;
    let mut last_mtime: Option<std::time::SystemTime> = None;

    let mut settings = load_settings(&settings_path);

    loop {
        // Read file modification time
        if let Ok(metadata) = fs::metadata(&settings_path)
            && let Ok(mtime) = metadata.modified()
                && last_mtime.is_none_or(|last| mtime > last) {
                    settings = load_settings(&settings_path);
                    last_mtime = Some(mtime);
                }

        // Read battery state
        let status = fs::read_to_string(bat_dir.join("status"))
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| "Unknown".to_string());

        let capacity = fs::read_to_string(bat_dir.join("capacity"))
            .ok()
            .and_then(|s| s.trim().parse::<i32>().ok())
            .unwrap_or(0);

        if settings.automation_enabled {
            let is_low = capacity < settings.low_battery_threshold;
            let was_low = last_capacity.is_some_and(|c| c < settings.low_battery_threshold);

            let status_changed = last_status.as_ref() != Some(&status);
            let low_crossed = is_low != was_low;

            if status_changed || low_crossed || last_status.is_none() {
                if status == "Charging" || status == "Full" {
                    if last_status.as_ref().is_none_or(|s| s != "Charging" && s != "Full") {
                        set_profile(&settings.ac_profile);
                        set_keyboard_brightness(settings.ac_kbd_brightness);
                        set_brightness(settings.ac_screen_brightness);
                        notify(
                            "Battery Automations",
                            &format!(
                                "AC connected. Profile: {}. Keyboard: {}%. Brightness: {}%",
                                settings.ac_profile, settings.ac_kbd_brightness, settings.ac_screen_brightness
                            ),
                            "battery-charging",
                        );
                    }
                } else {
                    if is_low {
                        if !was_low || status_changed || last_status.is_none() {
                            set_profile(&settings.low_profile);
                            set_keyboard_brightness(settings.low_kbd_brightness);
                            set_brightness(settings.low_screen_brightness);
                            notify(
                                "Battery Automations",
                                &format!(
                                    "Low Battery ({}%). Profile: {}. Keyboard: {}%. Brightness: {}%",
                                    capacity, settings.low_profile, settings.low_kbd_brightness, settings.low_screen_brightness
                                ),
                                "battery-low",
                            );
                        }
                    } else {
                        if was_low || status_changed || last_status.is_none() {
                            set_profile(&settings.bat_profile);
                            set_keyboard_brightness(settings.bat_kbd_brightness);
                            set_brightness(settings.bat_screen_brightness);
                            notify(
                                "Battery Automations",
                                &format!(
                                    "On Battery ({}%). Profile: {}. Keyboard: {}%. Brightness: {}%",
                                    capacity, settings.bat_profile, settings.bat_kbd_brightness, settings.bat_screen_brightness
                                ),
                                "battery",
                            );
                        }
                    }
                }
            }
        }

        last_status = Some(status);
        last_capacity = Some(capacity);
        std::thread::sleep(std::time::Duration::from_secs(3));
    }
}
