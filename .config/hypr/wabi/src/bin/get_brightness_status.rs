use wabi::{brightnessctl_percent, find_kbd_backlight_device, print_json, read_trimmed};
use serde::Serialize;
use std::path::Path;

#[derive(Serialize)]
struct BrightnessStatus {
    screen_brightness_pct: i32,
    kbd_brightness_pct: i32,
    kbd_device: String,
    sunset_state: String,
    caffeine_active: bool,
}

fn get_sunset_state() -> String {
    let home = std::env::var("HOME").unwrap_or_default();
    let state_file = Path::new(&home).join(".config/hypr/sunset.state");
    read_trimmed(&state_file).unwrap_or_else(|| "Off".to_string())
}

fn is_caffeine_active() -> bool {
    Path::new("/tmp/caffeine-mode").exists()
}

fn main() {
    let kbd_device = find_kbd_backlight_device().unwrap_or_default();
    let kbd_brightness_pct = if kbd_device.is_empty() {
        0
    } else {
        brightnessctl_percent(Some(&kbd_device))
    };

    let status = BrightnessStatus {
        screen_brightness_pct: brightnessctl_percent(None),
        kbd_brightness_pct,
        kbd_device,
        sunset_state: get_sunset_state(),
        caffeine_active: is_caffeine_active(),
    };
    print_json(&status);
}
