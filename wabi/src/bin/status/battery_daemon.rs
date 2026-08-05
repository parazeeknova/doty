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

fn default_true() -> bool {
    true
}
fn default_threshold() -> i32 {
    25
}
fn default_low_profile() -> String {
    "Quiet".to_string()
}
fn default_bat_profile() -> String {
    "Balanced".to_string()
}
fn default_ac_profile() -> String {
    "Performance".to_string()
}
fn default_bat_screen() -> i32 {
    70
}
fn default_bat_kbd() -> i32 {
    33
}
fn default_ac_screen() -> i32 {
    100
}
fn default_ac_kbd() -> i32 {
    90
}
fn default_low_screen() -> i32 {
    30
}
fn default_low_kbd() -> i32 {
    0
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
enum PowerState {
    AC,
    Battery,
    LowBattery,
}

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

fn notify_desktop(title: &str, message: &str, icon: &str) {
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
        let max_path = Path::new("/sys/class/leds")
            .join(&dev)
            .join("max_brightness");
        if let Ok(content) = fs::read_to_string(&max_path)
            && let Ok(max_val) = content.trim().parse::<f64>()
        {
            let val = ((percent as f64 / 100.0) * max_val).round() as i32;
            let _ = Command::new("brightnessctl")
                .args(["-d", &dev, "set", &val.to_string()])
                .status();
        }
    }
}

fn is_ac_online() -> bool {
    let root = Path::new("/sys/class/power_supply");
    if let Ok(entries) = fs::read_dir(root) {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Ok(kind) = fs::read_to_string(path.join("type")) {
                let kind_str = kind.trim();
                if (kind_str.eq_ignore_ascii_case("Mains")
                    || kind_str.eq_ignore_ascii_case("USB")
                    || kind_str.eq_ignore_ascii_case("ADP"))
                    && let Ok(online) = fs::read_to_string(path.join("online"))
                    && online.trim() == "1"
                {
                    return true;
                }
            }
        }
    }
    false
}

fn determine_power_state(
    bat_dir: &Path,
    threshold: i32,
    last_capacity: Option<i32>,
) -> (PowerState, i32) {
    let raw_status = fs::read_to_string(bat_dir.join("status"))
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "Unknown".to_string());

    let raw_capacity = fs::read_to_string(bat_dir.join("capacity"))
        .ok()
        .and_then(|s| s.trim().parse::<i32>().ok());

    let capacity = match raw_capacity {
        Some(c) if c > 0 => c,
        _ => last_capacity.unwrap_or(50),
    };

    let ac = is_ac_online()
        || raw_status == "Charging"
        || raw_status == "Full"
        || (raw_status == "Not charging" && is_ac_online());

    let state = if ac {
        PowerState::AC
    } else if capacity < threshold {
        PowerState::LowBattery
    } else {
        PowerState::Battery
    };

    (state, capacity)
}

fn main() {
    let Some(bat_dir) = wabi::find_battery_dir() else {
        eprintln!("No battery supply found. Exiting daemon.");
        std::process::exit(0);
    };

    let home = std::env::var("HOME").unwrap_or_default();
    let settings_path = Path::new(&home).join(".config/quickshell/battery_popup/settings.json");

    let mut current_state: Option<PowerState> = None;
    let mut last_capacity: Option<i32> = None;
    let mut last_mtime: Option<std::time::SystemTime> = None;

    let mut settings = load_settings(&settings_path);

    loop {
        // Reload settings if file was modified
        if let Ok(metadata) = fs::metadata(&settings_path)
            && let Ok(mtime) = metadata.modified()
            && last_mtime.is_none_or(|last| mtime > last)
        {
            settings = load_settings(&settings_path);
            last_mtime = Some(mtime);
        }

        if settings.automation_enabled {
            let (new_state, capacity) =
                determine_power_state(&bat_dir, settings.low_battery_threshold, last_capacity);

            let state_changed = current_state != Some(new_state);

            if state_changed {
                match new_state {
                    PowerState::AC => {
                        set_profile(&settings.ac_profile);
                        set_keyboard_brightness(settings.ac_kbd_brightness);
                        set_brightness(settings.ac_screen_brightness);

                        // Only notify on state transitions after startup
                        if current_state.is_some() {
                            notify_desktop(
                                "Battery Automations",
                                &format!(
                                    "AC Connected ({}%). Profile: {}. Keyboard: {}%. Brightness: {}%",
                                    capacity,
                                    settings.ac_profile,
                                    settings.ac_kbd_brightness,
                                    settings.ac_screen_brightness
                                ),
                                "battery-charging",
                            );
                        }
                    }
                    PowerState::LowBattery => {
                        set_profile(&settings.low_profile);
                        set_keyboard_brightness(settings.low_kbd_brightness);
                        set_brightness(settings.low_screen_brightness);

                        if current_state.is_some() {
                            notify_desktop(
                                "Battery Automations",
                                &format!(
                                    "Low Battery ({}%). Profile: {}. Keyboard: {}%. Brightness: {}%",
                                    capacity,
                                    settings.low_profile,
                                    settings.low_kbd_brightness,
                                    settings.low_screen_brightness
                                ),
                                "battery-low",
                            );
                        }
                    }
                    PowerState::Battery => {
                        set_profile(&settings.bat_profile);
                        set_keyboard_brightness(settings.bat_kbd_brightness);
                        set_brightness(settings.bat_screen_brightness);

                        if current_state.is_some() {
                            notify_desktop(
                                "Battery Automations",
                                &format!(
                                    "On Battery ({}%). Profile: {}. Keyboard: {}%. Brightness: {}%",
                                    capacity,
                                    settings.bat_profile,
                                    settings.bat_kbd_brightness,
                                    settings.bat_screen_brightness
                                ),
                                "battery",
                            );
                        }
                    }
                }
                current_state = Some(new_state);
            }
            last_capacity = Some(capacity);
        }

        std::thread::sleep(std::time::Duration::from_secs(3));
    }
}
