use serde::{Deserialize, Serialize};
use std::fs;
use std::process::Command;
use wabi::{battery_snapshot, print_json, quickshell_dir, round_to};

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

fn main() {
    let config_dir = quickshell_dir().join("battery_popup");
    let history_file = config_dir.join("history.json");

    let battery = battery_snapshot();
    let status = battery.status.clone();
    let mut health = 100.0;
    if battery.full_design > 0.0 {
        health = (battery.full / battery.full_design) * 100.0;
    }

    let power_draw_w = battery.power_w;

    let time_remaining_str = if status == "Charging" {
        if battery.rate > 0.0 {
            let rem_charge = (battery.full - battery.now).max(0.0);
            let hours = rem_charge / battery.rate;
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
        if battery.rate > 0.0 {
            let hours = battery.now / battery.rate;
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
        capacity: battery.capacity,
        status,
        health: round_to(health, 10.0),
        power_draw_w: round_to(power_draw_w, 100.0),
        time_remaining_str,
        active_profile,
        sparkline,
        history,
    };

    print_json(&result);
}
