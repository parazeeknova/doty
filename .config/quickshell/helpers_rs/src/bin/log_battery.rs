use helpers_rs::{battery_snapshot, quickshell_dir, round_to};
use std::fs;

fn main() {
    let config_dir = quickshell_dir().join("battery_popup");
    let history_file = config_dir.join("history.json");
    let battery = battery_snapshot();

    let mut power_draw = 0.0;
    if battery.status == "Discharging" && battery.power_w > 0.0 {
        power_draw = round_to(battery.power_w, 100.0);
    }

    let mut history: Vec<f64> = fs::read_to_string(&history_file)
        .ok()
        .and_then(|content| serde_json::from_str(&content).ok())
        .unwrap_or_else(|| vec![0.0; 10]);

    history.push(power_draw);
    if history.len() > 10 {
        history = history[history.len() - 10..].to_vec();
    }

    if fs::create_dir_all(&config_dir).is_ok()
        && let Ok(json_str) = serde_json::to_string(&history)
    {
        let _ = fs::write(&history_file, json_str);
    }
}
