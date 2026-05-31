use std::fs;
use std::path::Path;

fn read_sys_file(path: &Path) -> String {
    fs::read_to_string(path)
        .map(|s| s.trim().to_string())
        .unwrap_or_default()
}

fn main() {
    let config_dir = Path::new("/home/parazeeknova/.config/quickshell/battery_popup");
    let history_file = config_dir.join("history.json");
    let bat_dir = Path::new("/sys/class/power_supply/BAT1");

    let status = read_sys_file(&bat_dir.join("status"));
    let current_now_str = read_sys_file(&bat_dir.join("current_now"));
    let voltage_now_str = read_sys_file(&bat_dir.join("voltage_now"));

    let current_now = current_now_str.parse::<f64>().unwrap_or(0.0);
    let voltage_now = voltage_now_str.parse::<f64>().unwrap_or(0.0);

    let mut power_draw = 0.0;
    if status == "Discharging" && current_now > 0.0 {
        power_draw = (voltage_now * current_now) / 1e12;
        power_draw = (power_draw * 100.0).round() / 100.0;
    }

    let mut history: Vec<f64> = fs::read_to_string(&history_file)
        .ok()
        .and_then(|content| serde_json::from_str(&content).ok())
        .unwrap_or_else(|| vec![0.0; 10]);

    history.push(power_draw);
    if history.len() > 10 {
        history = history[history.len() - 10..].to_vec();
    }

    if fs::create_dir_all(config_dir).is_ok() {
        if let Ok(json_str) = serde_json::to_string(&history) {
            let _ = fs::write(&history_file, json_str);
        } else {
            // handle error implicitly
        }
    }
}
