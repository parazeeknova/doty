use std::fs;
use std::path::{Path, PathBuf};

use crate::state_file::read_trimmed;

#[derive(Clone, Debug, Default)]
pub struct BatterySnapshot {
    pub capacity: i32,
    pub status: String,
    pub full: f64,
    pub full_design: f64,
    pub now: f64,
    pub power_w: f64,
    pub rate: f64,
}

fn parse_num(path: &Path) -> f64 {
    read_trimmed(path)
        .and_then(|s| s.parse::<f64>().ok())
        .unwrap_or(0.0)
}

pub fn find_battery_dir() -> Option<PathBuf> {
    let root = Path::new("/sys/class/power_supply");
    let entries = fs::read_dir(root).ok()?;
    let mut candidates: Vec<PathBuf> = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| {
            read_trimmed(&path.join("type"))
                .map(|kind| kind.eq_ignore_ascii_case("battery"))
                .unwrap_or(false)
        })
        .collect();
    candidates.sort();
    candidates.into_iter().next()
}

pub fn battery_snapshot() -> BatterySnapshot {
    let Some(dir) = find_battery_dir() else {
        return BatterySnapshot {
            status: "Unknown".to_string(),
            ..BatterySnapshot::default()
        };
    };

    let capacity = read_trimmed(&dir.join("capacity"))
        .and_then(|s| s.parse::<i32>().ok())
        .unwrap_or(0);
    let status = read_trimmed(&dir.join("status")).unwrap_or_else(|| "Unknown".to_string());

    let energy_full = parse_num(&dir.join("energy_full"));
    let energy_full_design = parse_num(&dir.join("energy_full_design"));
    let energy_now = parse_num(&dir.join("energy_now"));
    let power_now = parse_num(&dir.join("power_now"));

    if energy_full > 0.0 || energy_now > 0.0 || power_now > 0.0 {
        return BatterySnapshot {
            capacity,
            status,
            full: energy_full,
            full_design: energy_full_design,
            now: energy_now,
            power_w: power_now / 1e6,
            rate: power_now,
        };
    }

    let charge_full = parse_num(&dir.join("charge_full"));
    let charge_full_design = parse_num(&dir.join("charge_full_design"));
    let charge_now = parse_num(&dir.join("charge_now"));
    let current_now = parse_num(&dir.join("current_now"));
    let voltage_now = parse_num(&dir.join("voltage_now"));

    BatterySnapshot {
        capacity,
        status,
        full: charge_full,
        full_design: charge_full_design,
        now: charge_now,
        power_w: (voltage_now * current_now) / 1e12,
        rate: current_now,
    }
}
