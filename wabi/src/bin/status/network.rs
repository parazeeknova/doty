use serde::Serialize;
use std::collections::{HashMap, HashSet};
use wabi::{active_wifi_device, cidr_to_netmask, print_json, run_cmd, split_nmcli_t_line};

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

fn is_wifi_enabled() -> bool {
    let out = run_cmd("nmcli", &["radio", "wifi"]).unwrap_or_default();
    out.to_lowercase().contains("enabled")
}

fn is_airplane_mode() -> bool {
    // Check if wifi and bluetooth are both blocked in rfkill
    let out = run_cmd("rfkill", &["-no", "TYPE,SOFT"]).unwrap_or_default();
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

fn wifi_autoconnect_by_ssid() -> HashMap<String, bool> {
    let out = run_cmd(
        "nmcli",
        &[
            "-t",
            "-f",
            "NAME,TYPE,802-11-wireless.ssid,connection.autoconnect",
            "connection",
            "show",
        ],
    )
    .unwrap_or_default();
    let mut map = HashMap::new();

    for line in out.lines() {
        let parts = split_nmcli_t_line(line);
        if parts.len() >= 4 && parts[1] == "802-11-wireless" {
            let ssid = if parts[2].is_empty() {
                parts[0].clone()
            } else {
                parts[2].clone()
            };
            map.insert(ssid, parts[3].eq_ignore_ascii_case("yes"));
        }
    }

    map
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let force_rescan = args.contains(&"--rescan".to_string());

    let wifi_enabled = is_wifi_enabled();
    let airplane_mode = is_airplane_mode();
    let wifi_device = active_wifi_device();

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
    let autoconnect_by_ssid = wifi_autoconnect_by_ssid();

    // 1. Get scanned wifi networks
    if wifi_enabled {
        let rescan_val = if force_rescan { "yes" } else { "no" };
        let wifi_list_out = run_cmd(
            "nmcli",
            &[
                "-t",
                "-f",
                "active,ssid,bssid,signal,rate,security",
                "dev",
                "wifi",
                "list",
                "--rescan",
                rescan_val,
            ],
        )
        .unwrap_or_default();

        // Keep track of SSIDs to avoid duplicates in scan list
        let mut seen_ssids = HashSet::new();

        for line in wifi_list_out.lines() {
            let parts = split_nmcli_t_line(line);

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
                    let iw_out = wifi_device
                        .as_deref()
                        .and_then(|dev| run_cmd("iw", &["dev", dev, "link"]))
                        .unwrap_or_default();
                    let mut rx_rate = String::new();
                    let mut tx_rate = String::new();
                    for iw_line in iw_out.lines() {
                        let trimmed = iw_line.trim();
                        if trimmed.starts_with("rx bitrate:") {
                            rx_rate = trimmed
                                .trim_start_matches("rx bitrate:")
                                .split_whitespace()
                                .take(2)
                                .collect::<Vec<&str>>()
                                .join(" ");
                        } else if trimmed.starts_with("tx bitrate:") {
                            tx_rate = trimmed
                                .trim_start_matches("tx bitrate:")
                                .split_whitespace()
                                .take(2)
                                .collect::<Vec<&str>>()
                                .join(" ");
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

                    let autoconnect = autoconnect_by_ssid.get(&ssid).copied().unwrap_or(false);

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

    // 2. Fetch IP details for the active Wi-Fi device if connected
    if connected && let Some(dev) = wifi_device.as_deref() {
        let dev_info = run_cmd("nmcli", &["dev", "show", dev]).unwrap_or_default();
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
                        if let Ok(prefix) = addr_parts[1].parse::<u32>()
                            && let Some(mask) = cidr_to_netmask(prefix)
                        {
                            details.subnet = mask;
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
    let vpn_out = run_cmd(
        "nmcli",
        &["-t", "-f", "name,type,device,active", "connection", "show"],
    )
    .unwrap_or_default();
    for line in vpn_out.lines() {
        let parts = split_nmcli_t_line(line);
        if parts.len() >= 4 {
            let name = parts[0].clone();
            let conn_type = parts[1].clone();
            let device = parts[2].clone();
            let active = parts[3].to_lowercase().contains("yes");

            // Filter for VPN / Wireguard / tun connections (excluding bridge, loopback, wifi, ethernet)
            let is_vpn = conn_type.contains("vpn")
                || conn_type.contains("wireguard")
                || conn_type.contains("tun");
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
    let warp_out = run_cmd("warp-cli", &["status"]).unwrap_or_default();
    let warp_connected = warp_out
        .lines()
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

    let cache_path = wabi::cache_dir().join("network_status.json");
    let _ = wabi::atomic_write_json(&cache_path, &status);

    print_json(&status);
}
