use serde::Serialize;
use wabi::{print_json, run_cmd};

#[derive(Serialize)]
struct WaybarOutput {
    text: String,
    tooltip: String,
    class: String,
}

fn main() {
    let ts_out = run_cmd("tailscale", &["status", "--json"]).unwrap_or_default();
    let mut tailscale_connected = false;
    let mut tailscale_ip = String::new();

    if let Ok(v) = serde_json::from_str::<serde_json::Value>(&ts_out) {
        if v.get("BackendState").and_then(|s| s.as_str()) == Some("Running") {
            tailscale_connected = true;
        }
        if let Some(ip) = v
            .get("Self")
            .and_then(|s| s.get("TailscaleIPs"))
            .and_then(|i| i.as_array())
            .and_then(|ips| ips.first())
            .and_then(|i| i.as_str())
        {
            tailscale_ip = ip.to_string();
        }
    }

    let (text, class, tooltip) = if tailscale_connected {
        (
            "T".to_string(),
            "connected".to_string(),
            format!("Tailscale: Connected ({})", tailscale_ip),
        )
    } else {
        (
            "T".to_string(),
            "disconnected".to_string(),
            "Tailscale: Disconnected".to_string(),
        )
    };

    let output = WaybarOutput {
        text,
        tooltip,
        class,
    };
    print_json(&output);
}
