use helpers_rs::print_json;
use serde::Serialize;
use std::collections::{HashMap, HashSet};
use std::process::Command;
use std::time::Duration;

#[derive(Serialize)]
struct BluetoothDevice {
    name: String,
    address: String,
    connected: bool,
    paired: bool,
    trusted: bool,
    battery: Option<f64>,
    device_type: String,
}

#[derive(Serialize)]
struct BluetoothStatus {
    enabled: bool,
    devices: Vec<BluetoothDevice>,
}

fn run_cmd(cmd: &str, args: &[&str]) -> String {
    helpers_rs::run_cmd(cmd, args).unwrap_or_default()
}

fn is_bluetooth_enabled() -> bool {
    let out = run_cmd("bluetoothctl", &["show"]);
    for line in out.lines() {
        if line.contains("Powered:") {
            return line.contains("yes");
        }
    }
    false
}

fn parse_upower_batteries() -> HashMap<String, f64> {
    let out = run_cmd("upower", &["-d"]);
    let mut batteries = HashMap::new();
    let mut current_address = String::new();

    for line in out.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("Device:") || trimmed.starts_with("native-path:") {
            current_address = String::new();
        }
        if let Some(serial) = trimmed.strip_prefix("serial:") {
            current_address = serial.trim().to_uppercase();
        } else if trimmed.starts_with("native-path:") {
            current_address = trimmed
                .trim_start_matches("native-path:")
                .trim()
                .replace('_', ":")
                .to_uppercase();
        }
        if trimmed.starts_with("percentage:") && !current_address.is_empty() {
            let pct_str = trimmed
                .trim_start_matches("percentage:")
                .trim()
                .trim_end_matches('%');
            if let Ok(pct) = pct_str.parse::<f64>() {
                batteries.insert(current_address.clone(), pct);
            }
        }
    }

    batteries
}

fn get_battery_for_device(address: &str, upower_batteries: &HashMap<String, f64>) -> Option<f64> {
    if let Some(pct) = upower_batteries.get(&address.to_uppercase()) {
        return Some(*pct);
    }
    for (device_key, pct) in upower_batteries {
        if device_key.contains(&address.to_uppercase()) {
            return Some(*pct);
        }
    }

    let bat_out = run_cmd("bluetoothctl", &["battery-info", address]);
    for line in bat_out.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("Battery Percentage:")
            && let Some(start) = trimmed.rfind('(')
            && let Some(end) = trimmed.rfind(')')
        {
            let pct_str = &trimmed[start + 1..end].trim_end_matches('%');
            if let Ok(pct) = pct_str.parse::<f64>() {
                return Some(pct);
            }
        }
    }

    None
}

fn classify_device_type(name: &str, info: &str) -> String {
    let info_lower = info.to_lowercase();
    if info_lower.contains("icon: audio")
        || info_lower.contains("audio sink")
        || info_lower.contains("audio source")
        || info_lower.contains("headset")
        || info_lower.contains("handsfree")
    {
        return "audio".to_string();
    }
    if info_lower.contains("icon: input-keyboard") || info_lower.contains("keyboard") {
        return "keyboard".to_string();
    }
    if info_lower.contains("icon: input-mouse") || info_lower.contains("mouse") {
        return "mouse".to_string();
    }
    if info_lower.contains("icon: input-gaming") || info_lower.contains("gamepad") {
        return "controller".to_string();
    }

    let lower = name.to_lowercase();
    if lower.contains("headphone")
        || lower.contains("headset")
        || lower.contains("earbuds")
        || lower.contains("earphone")
        || lower.contains("airpods")
        || lower.contains("buds")
        || lower.contains("qc")
        || lower.contains("wh-")
        || lower.contains("wf-")
        || lower.contains("beats")
        || lower.contains("jabra")
        || lower.contains("sony")
    {
        "audio".to_string()
    } else if lower.contains("keyboard") || lower.contains("keychron") {
        "keyboard".to_string()
    } else if lower.contains("mouse")
        || lower.contains("logitech")
        || lower.contains("g502")
        || lower.contains("g pro")
        || lower.contains("deathadder")
    {
        "mouse".to_string()
    } else if lower.contains("controller")
        || lower.contains("xbox")
        || lower.contains("ps5")
        || lower.contains("dualshock")
        || lower.contains("dualsense")
    {
        "controller".to_string()
    } else {
        "device".to_string()
    }
}

fn do_scan() {
    let _ = Command::new("bluetoothctl").args(["scan", "on"]).output();
    std::thread::sleep(Duration::from_millis(1500));
    let _ = Command::new("bluetoothctl").args(["scan", "off"]).output();
}

fn get_devices(should_scan: bool) -> Vec<BluetoothDevice> {
    let mut devices = Vec::new();
    let mut known_addresses = HashSet::new();
    let upower_batteries = parse_upower_batteries();

    // Get all known devices from bluetoothctl
    let devices_out = run_cmd("bluetoothctl", &["devices"]);
    let mut addresses: Vec<(String, String)> = Vec::new();

    for line in devices_out.lines() {
        if line.starts_with("Device ") {
            let rest = line.trim_start_matches("Device ");
            if let Some(space_idx) = rest.find(' ') {
                let addr = rest[..space_idx].to_string();
                let name = rest[space_idx + 1..].to_string();
                known_addresses.insert(addr.clone());
                addresses.push((addr, name));
            }
        }
    }

    // Optionally scan for nearby devices
    if should_scan {
        do_scan();

        // Re-fetch devices after scan to pick up newly discovered ones
        let devices_out_after = run_cmd("bluetoothctl", &["devices"]);
        for line in devices_out_after.lines() {
            if line.starts_with("Device ") {
                let rest = line.trim_start_matches("Device ");
                if let Some(space_idx) = rest.find(' ') {
                    let addr = rest[..space_idx].to_string();
                    let name = rest[space_idx + 1..].to_string();
                    if !known_addresses.contains(&addr) {
                        known_addresses.insert(addr.clone());
                        addresses.push((addr, name));
                    }
                }
            }
        }
    }

    // Get info for each device
    for (addr, name) in &addresses {
        let info_out = run_cmd("bluetoothctl", &["info", addr]);
        let mut connected = false;
        let mut paired = false;
        let mut trusted = false;

        for line in info_out.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("Connected:") {
                connected = trimmed.contains("yes");
            } else if trimmed.starts_with("Paired:") {
                paired = trimmed.contains("yes");
            } else if trimmed.starts_with("Trusted:") {
                trusted = trimmed.contains("yes");
            }
        }

        let battery = get_battery_for_device(addr, &upower_batteries);
        let device_type = classify_device_type(name, &info_out);

        devices.push(BluetoothDevice {
            name: name.clone(),
            address: addr.clone(),
            connected,
            paired,
            trusted,
            battery,
            device_type,
        });
    }

    // Sort: connected first, then by battery presence, then by name
    devices.sort_by(|a, b| {
        if a.connected != b.connected {
            b.connected.cmp(&a.connected)
        } else if a.battery.is_some() != b.battery.is_some() {
            b.battery.is_some().cmp(&a.battery.is_some())
        } else {
            a.name.cmp(&b.name)
        }
    });

    devices
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let do_scan = args.iter().any(|a| a == "--scan");

    let enabled = is_bluetooth_enabled();
    let devices = if enabled {
        get_devices(do_scan)
    } else {
        Vec::new()
    };

    let status = BluetoothStatus { enabled, devices };

    print_json(&status);
}
