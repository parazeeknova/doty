use std::process::Command;
use serde::Serialize;

#[derive(Serialize)]
struct WifiNetwork {
    ssid: String,
    bssid: String,
    signal: i32,
    rate: String,
    security: String,
    active: bool,
    autoconnect: bool,
}

#[derive(Serialize)]
struct VpnConnection {
    name: String,
    vpn_type: String,
    device: String,
    active: bool,
}

#[derive(Serialize)]
struct ConnectionDetails {
    ip_address: String,
    gateway: String,
    dns: String,
    subnet: String,
    security: String,
    bssid: String,
}

#[derive(Serialize)]
struct NetworkStatus {
    wifi_enabled: bool,
    airplane_mode: bool,
    connected: bool,
    active_ssid: String,
    active_signal: i32,
    active_speed: String,
    warp_connected: bool,
    details: ConnectionDetails,
    networks: Vec<WifiNetwork>,
    vpns: Vec<VpnConnection>,
}

fn run_cmd(cmd: &str, args: &[&str]) -> String {
    Command::new(cmd)
        .args(args)
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_default()
}

fn is_wifi_enabled() -> bool {
    let out = run_cmd("nmcli", &["radio", "wifi"]);
    out.to_lowercase().contains("enabled")
}

fn is_airplane_mode() -> bool {
    // Check if wifi and bluetooth are both blocked in rfkill
    let out = run_cmd("rfkill", &["-no", "TYPE,SOFT"]);
    let lines = out.lines();
    let mut wlan_blocked = false;
    let mut bt_blocked = false;
    let mut has_wlan = false;
    let mut has_bt = false;

    for line in lines {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 2 {
            let t = parts[0].to_lowercase();
            let blocked = parts[1].to_lowercase() == "blocked";
            if t.contains("wlan") || t.contains("wifi") {
                has_wlan = true;
                if blocked {
                    wlan_blocked = true;
                }
            } else if t.contains("bluetooth") {
                has_bt = true;
                if blocked {
                    bt_blocked = true;
                }
            }
        }
    }

    if has_wlan && has_bt {
        wlan_blocked && bt_blocked
    } else if has_wlan {
        wlan_blocked
    } else {
        false
    }
}

fn main() {
    let wifi_enabled = is_wifi_enabled();
    let airplane_mode = is_airplane_mode();

    let mut connected = false;
    let mut active_ssid = String::new();
    let mut active_signal = 0;
    let mut active_speed = String::new();

    let mut details = ConnectionDetails {
        ip_address: String::new(),
        gateway: String::new(),
        dns: String::new(),
        subnet: String::new(),
        security: String::new(),
        bssid: String::new(),
    };

    let mut networks: Vec<WifiNetwork> = Vec::new();
    let mut vpns: Vec<VpnConnection> = Vec::new();

    // 1. Get scanned wifi networks
    if wifi_enabled {
        let wifi_list_out = run_cmd(
            "nmcli",
            &["-t", "-f", "active,ssid,bssid,signal,rate,security", "dev", "wifi", "list", "--rescan", "auto"],
        );

        // Keep track of SSIDs to avoid duplicates in scan list
        let mut seen_ssids = std::collections::HashSet::new();

        for line in wifi_list_out.lines() {
            // Split fields by ':' but handle escaped colons in BSSID
            // Format: active:ssid:bssid:signal:rate:security
            // Colons in BSSID are escaped with backslash
            let mut parts = Vec::new();
            let mut current = String::new();
            let mut chars = line.chars().peekable();

            while let Some(c) = chars.next() {
                if c == '\\' && chars.peek() == Some(&':') {
                    current.push(':');
                    chars.next();
                } else if c == ':' {
                    parts.push(current.clone());
                    current.clear();
                } else {
                    current.push(c);
                }
            }
            parts.push(current);

            if parts.len() >= 6 {
                let active = parts[0].to_lowercase().contains("yes");
                let ssid = parts[1].trim().to_string();
                let bssid = parts[2].trim().to_string();
                let signal = parts[3].trim().parse::<i32>().unwrap_or(0);
                let rate = parts[4].trim().to_string();
                let security = parts[5].trim().to_string();

                if ssid.is_empty() {
                    continue;
                }

                if active {
                    connected = true;
                    active_ssid = ssid.clone();
                    active_signal = signal;
                    details.security = security.clone();
                    details.bssid = bssid.clone();

                    // Get real negotiated bitrate from iw instead of PHY link rate
                    let iw_out = run_cmd("iw", &["dev", "wlan0", "link"]);
                    let mut rx_rate = String::new();
                    let mut tx_rate = String::new();
                    for iw_line in iw_out.lines() {
                        let trimmed = iw_line.trim();
                        if trimmed.starts_with("rx bitrate:") {
                            rx_rate = trimmed.trim_start_matches("rx bitrate:").trim()
                                .split_whitespace().take(2).collect::<Vec<&str>>().join(" ");
                        } else if trimmed.starts_with("tx bitrate:") {
                            tx_rate = trimmed.trim_start_matches("tx bitrate:").trim()
                                .split_whitespace().take(2).collect::<Vec<&str>>().join(" ");
                        }
                    }
                    if !tx_rate.is_empty() {
                        // Normalize "MBit/s" to "Mbps"
                        let tx_clean = tx_rate.replace("MBit/s", "Mbps");
                        let rx_clean = rx_rate.replace("MBit/s", "Mbps");
                        active_speed = format!("↓{} ↑{}", rx_clean, tx_clean);
                    } else {
                        active_speed = rate.clone();
                    }
                }

                if !seen_ssids.contains(&ssid) {
                    seen_ssids.insert(ssid.clone());
                    
                    // Check autoconnect setting for this connection name
                    let autoconnect_out = run_cmd("nmcli", &["-g", "connection.autoconnect", "connection", "show", &ssid]);
                    let autoconnect = autoconnect_out.to_lowercase().contains("yes");

                    networks.push(WifiNetwork {
                        ssid,
                        bssid,
                        signal,
                        rate,
                        security,
                        active,
                        autoconnect,
                    });
                }
            }
        }
    }

    // Sort networks: active first, then by signal strength desc
    networks.sort_by(|a, b| {
        if a.active != b.active {
            b.active.cmp(&a.active)
        } else {
            b.signal.cmp(&a.signal)
        }
    });

    // 2. Fetch IP details for wlan0 if connected
    if connected {
        let dev_info = run_cmd("nmcli", &["dev", "show", "wlan0"]);
        for line in dev_info.lines() {
            let parts: Vec<&str> = line.splitn(2, ':').collect();
            if parts.len() == 2 {
                let key = parts[0].trim();
                let val = parts[1].trim().to_string();
                if key.contains("IP4.ADDRESS") {
                    // format: 192.168.1.10/24
                    let addr_parts: Vec<&str> = val.split('/').collect();
                    details.ip_address = addr_parts[0].to_string();
                    if addr_parts.len() >= 2 {
                        // Calculate subnet mask from CIDR prefix
                        if let Ok(prefix) = addr_parts[1].parse::<u32>() {
                            let mask = !0u32 << (32 - prefix);
                            details.subnet = format!(
                                "{}.{}.{}.{}",
                                (mask >> 24) & 0xFF,
                                (mask >> 16) & 0xFF,
                                (mask >> 8) & 0xFF,
                                mask & 0xFF
                            );
                        }
                    }
                } else if key.contains("IP4.GATEWAY") {
                    details.gateway = val;
                } else if key.contains("IP4.DNS") {
                    if details.dns.is_empty() {
                        details.dns = val;
                    } else {
                        details.dns = format!("{}, {}", details.dns, val);
                    }
                }
            }
        }
    }

    // 3. Get NM VPN / Wireguard / tunnel connections
    let vpn_out = run_cmd("nmcli", &["-t", "-f", "name,type,device,active", "connection", "show"]);
    for line in vpn_out.lines() {
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() >= 4 {
            let name = parts[0].to_string();
            let conn_type = parts[1].to_string();
            let device = parts[2].to_string();
            let active = parts[3].to_lowercase().contains("yes");

            // Filter for VPN / Wireguard / tun connections (excluding bridge, loopback, wifi, ethernet)
            let is_vpn = conn_type.contains("vpn") || conn_type.contains("wireguard") || conn_type.contains("tun");
            if is_vpn && !device.is_empty() && device != "lo" && !device.starts_with("virbr") {
                vpns.push(VpnConnection {
                    name,
                    vpn_type: conn_type,
                    device,
                    active,
                });
            }
        }
    }

    // 4. Check WARP status
    let warp_out = run_cmd("warp-cli", &["status"]);
    let warp_connected = warp_out.lines()
        .any(|l| l.to_lowercase().contains("status update: connected"));

    let status = NetworkStatus {
        wifi_enabled,
        airplane_mode,
        connected,
        active_ssid,
        active_signal,
        active_speed,
        warp_connected,
        details,
        networks,
        vpns,
    };

    if let Ok(json_str) = serde_json::to_string(&status) {
        println!("{}", json_str);
    }
}
