use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::process::Command;

#[derive(Serialize, Deserialize, Debug)]
struct BatteryResult {
    capacity: i32,
    status: String,
    health: f64,
    #[serde(rename = "power_draw_w")]
    power_draw_w: f64,
    time_remaining_str: String,
    active_profile: String,
    sparkline: String,
    history: Vec<f64>,
}

fn read_sys_file(path: &Path) -> String {
    fs::read_to_string(path)
        .map(|s| s.trim().to_string())
        .unwrap_or_default()
}

fn main() {
    let config_dir = Path::new("/home/parazeeknova/.config/quickshell/battery_popup");
    let history_file = config_dir.join("history.json");
    let bat_dir = Path::new("/sys/class/power_supply/BAT1");

    let capacity_str = read_sys_file(&bat_dir.join("capacity"));
    let status = {
        let s = read_sys_file(&bat_dir.join("status"));
        if s.is_empty() {
            "Unknown".to_string()
        } else {
            s
        }
    };
    let charge_full_str = read_sys_file(&bat_dir.join("charge_full"));
    let charge_full_design_str = read_sys_file(&bat_dir.join("charge_full_design"));
    let charge_now_str = read_sys_file(&bat_dir.join("charge_now"));
    let current_now_str = read_sys_file(&bat_dir.join("current_now"));
    let voltage_now_str = read_sys_file(&bat_dir.join("voltage_now"));

    let capacity = capacity_str.parse::<i32>().unwrap_or(0);
    let charge_full = charge_full_str.parse::<f64>().unwrap_or(0.0);
    let charge_full_design = charge_full_design_str.parse::<f64>().unwrap_or(0.0);
    let charge_now = charge_now_str.parse::<f64>().unwrap_or(0.0);
    let current_now = current_now_str.parse::<f64>().unwrap_or(0.0);
    let voltage_now = voltage_now_str.parse::<f64>().unwrap_or(0.0);

    let mut health = 100.0;
    if charge_full_design > 0.0 {
        health = (charge_full / charge_full_design) * 100.0;
    }

    let power_draw_w = (voltage_now * current_now) / 1e12;

    let time_remaining_str = if status == "Charging" {
        if current_now > 0.0 {
            let rem_charge = charge_full - charge_now;
            let hours = rem_charge / current_now;
            let h = hours as i32;
            let m = ((hours - h as f64) * 60.0) as i32;
            if h > 0 {
                format!("{}h {}m until full", h, m)
            } else {
                format!("{}m until full", m)
            }
        } else {
            "Not charging".to_string()
        }
    } else if status == "Discharging" {
        if current_now > 0.0 {
            let hours = charge_now / current_now;
            let h = hours as i32;
            let m = ((hours - h as f64) * 60.0) as i32;
            if h > 0 {
                format!("{}h {}m remaining", h, m)
            } else {
                format!("{}m remaining", m)
            }
        } else {
            "N/A".to_string()
        }
    } else if status == "Full" {
        "Full".to_string()
    } else {
        "N/A".to_string()
    };

    let mut active_profile = "Unknown".to_string();
    if let Ok(output) = Command::new("asusctl").args(["profile", "get"]).output() {
        if !output.status.success() {
            // handle failure implicitly
        } else {
            let out_str = String::from_utf8_lossy(&output.stdout);
            for line in out_str.lines() {
                if let Some(suffix) = line.strip_prefix("Active profile:") {
                    active_profile = suffix.trim().to_string();
                    break;
                }
            }
        }
    }

    let history: Vec<f64> = fs::read_to_string(&history_file)
        .ok()
        .and_then(|content| serde_json::from_str(&content).ok())
        .unwrap_or_else(|| vec![0.0; 10]);

    let bars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"];
    let max_val = history.iter().cloned().fold(0.0, f64::max);

    let mut sparkline_chars = Vec::new();
    for &val in &history {
        if max_val > 0.0 {
            let mut idx = ((val / max_val) * (bars.len() - 1) as f64) as usize;
            if idx >= bars.len() {
                idx = bars.len() - 1;
            }
            sparkline_chars.push(bars[idx]);
        } else {
            sparkline_chars.push(bars[0]);
        }
    }
    let sparkline = sparkline_chars.concat();

    let result = BatteryResult {
        capacity,
        status,
        health: (health * 10.0).round() / 10.0,
        power_draw_w: (power_draw_w * 100.0).round() / 100.0,
        time_remaining_str,
        active_profile,
        sparkline,
        history,
    };

    if let Ok(json_out) = serde_json::to_string(&result) {
        println!("{}", json_out);
    }
}
