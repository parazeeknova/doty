use std::fs;

use crate::command::run_cmd;

pub fn parse_percent(value: &str) -> Option<i64> {
    let pct = value.split('%').next()?.trim();
    pct.parse::<f64>().ok().map(|v| v.round() as i64)
}

pub fn brightnessctl_percent(device: Option<&str>) -> i32 {
    let out = if let Some(device) = device {
        run_cmd("brightnessctl", &["-d", device, "-m"]).unwrap_or_default()
    } else {
        run_cmd("brightnessctl", &["-m"]).unwrap_or_default()
    };
    let parts: Vec<&str> = out.split(',').collect();
    parts
        .get(3)
        .and_then(|value| parse_percent(value))
        .map(|value| value.clamp(0, 100) as i32)
        .unwrap_or(0)
}

pub fn find_kbd_backlight_device() -> Option<String> {
    let entries = fs::read_dir("/sys/class/leds").ok()?;
    let mut candidates: Vec<String> = entries
        .flatten()
        .filter_map(|entry| entry.file_name().to_str().map(|name| name.to_string()))
        .filter(|name| name.ends_with("kbd_backlight"))
        .collect();
    candidates.sort();
    candidates.into_iter().next()
}

pub fn split_nmcli_t_line(line: &str) -> Vec<String> {
    let mut parts = Vec::new();
    let mut current = String::new();
    let mut chars = line.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '\\' {
            if let Some(next) = chars.next() {
                current.push(next);
            }
        } else if c == ':' {
            parts.push(current);
            current = String::new();
        } else {
            current.push(c);
        }
    }
    parts.push(current);
    parts
}

pub fn cidr_to_netmask(prefix: u32) -> Option<String> {
    if prefix > 32 {
        return None;
    }
    let mask = if prefix == 0 {
        0
    } else {
        u32::MAX << (32 - prefix)
    };
    Some(format!(
        "{}.{}.{}.{}",
        (mask >> 24) & 0xFF,
        (mask >> 16) & 0xFF,
        (mask >> 8) & 0xFF,
        mask & 0xFF
    ))
}

pub fn active_wifi_device() -> Option<String> {
    let out = run_cmd("nmcli", &["-t", "-f", "DEVICE,TYPE,STATE", "dev"])?;
    for line in out.lines() {
        let parts = split_nmcli_t_line(line);
        if parts.len() >= 3 && parts[1] == "wifi" && parts[2].contains("connected") {
            return Some(parts[0].clone());
        }
    }
    for line in out.lines() {
        let parts = split_nmcli_t_line(line);
        if parts.len() >= 2 && parts[1] == "wifi" {
            return Some(parts[0].clone());
        }
    }
    None
}

pub fn wpctl_get_volume(device: &str) -> Option<(f64, bool)> {
    let stdout = run_cmd("wpctl", &["get-volume", device])?;
    let vol_str = stdout.strip_prefix("Volume: ")?;
    let mut muted = false;
    let mut vol = vol_str;
    if let Some(rest) = vol.strip_suffix(" [MUTED]") {
        muted = true;
        vol = rest;
    }
    let pct = vol.parse::<f64>().ok()?;
    Some((pct, muted))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_escaped_nmcli_fields() {
        let fields = split_nmcli_t_line("yes:My\\:Wifi:AA\\:BB\\:CC:80:540 Mbit/s:WPA2");
        assert_eq!(fields[1], "My:Wifi");
        assert_eq!(fields[2], "AA:BB:CC");
    }

    #[test]
    fn converts_cidr_to_netmask() {
        assert_eq!(cidr_to_netmask(24).as_deref(), Some("255.255.255.0"));
        assert_eq!(cidr_to_netmask(0).as_deref(), Some("0.0.0.0"));
        assert!(cidr_to_netmask(33).is_none());
    }

    #[test]
    fn parses_decimal_percent() {
        assert_eq!(parse_percent("12.5%"), Some(13));
        assert_eq!(parse_percent("100%"), Some(100));
    }
}
