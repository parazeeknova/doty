use serde::Serialize;
use serde_json::Value;
use wabi::{print_json, run_cmd};

#[derive(Serialize)]
struct NotifItem {
    id: i64,
    app_name: String,
    summary: String,
    body: String,
    urgency: String,
    app_icon: String,
}

#[derive(Serialize)]
struct NotifStatus {
    active: Vec<NotifItem>,
    history: Vec<NotifItem>,
    bt_enabled: bool,
    wifi_enabled: bool,
    audio_muted: bool,
    uptime: String,
}

fn parse_items(raw_json: &str) -> Vec<NotifItem> {
    let mut items = Vec::new();
    if let Ok(value) = serde_json::from_str::<Value>(raw_json) {
        collect_items(&value, &mut items);
    }
    items
}

fn collect_items(value: &Value, items: &mut Vec<NotifItem>) {
    match value {
        Value::Array(arr) => {
            for item in arr {
                collect_items(item, items);
            }
        }
        Value::Object(obj) if looks_like_notification(value) => {
            let id = obj.get("id").and_then(|v| v.as_i64()).unwrap_or(0);
            let app_name = get_string(value, &["app_name", "app-name", "appName"])
                .unwrap_or("System")
                .to_string();
            let summary = get_string(value, &["summary"]).unwrap_or("").to_string();
            let body = get_string(value, &["body"]).unwrap_or("").to_string();
            let urgency = get_urgency(value);
            let app_icon = get_string(value, &["app_icon", "app-icon", "appIcon"])
                .unwrap_or("")
                .to_string();

            items.push(NotifItem {
                id,
                app_name,
                summary,
                body,
                urgency,
                app_icon,
            });
        }
        Value::Object(obj) => {
            for key in ["data", "notifications", "items", "history"] {
                if let Some(child) = obj.get(key) {
                    collect_items(child, items);
                }
            }
        }
        _ => {}
    }
}

fn looks_like_notification(value: &Value) -> bool {
    value.get("summary").is_some()
        || value.get("body").is_some()
        || value.get("app_name").is_some()
        || value.get("app-name").is_some()
}

fn get_string<'a>(value: &'a Value, keys: &[&str]) -> Option<&'a str> {
    keys.iter().find_map(|key| value.get(*key)?.as_str())
}

fn get_urgency(value: &Value) -> String {
    if let Some(urgency) = get_string(value, &["urgency"]) {
        return urgency.to_lowercase();
    }
    match value.get("urgency").and_then(|v| v.as_i64()).unwrap_or(1) {
        0 => "low".to_string(),
        2 => "critical".to_string(),
        _ => "normal".to_string(),
    }
}

fn is_bluetooth_enabled() -> bool {
    let out = run_cmd("bluetoothctl", &["show"]).unwrap_or_default();
    out.lines().any(|line| line.contains("Powered: yes"))
}

fn is_wifi_enabled() -> bool {
    let out = run_cmd("nmcli", &["radio", "wifi"]).unwrap_or_default();
    out.to_lowercase().contains("enabled")
}

fn is_audio_muted() -> bool {
    let pactl_out = run_cmd("pactl", &["get-sink-mute", "@DEFAULT_SINK@"]).unwrap_or_default();
    if pactl_out.contains("Mute: yes") {
        return true;
    }
    let wpctl_out = run_cmd("wpctl", &["get-volume", "@DEFAULT_AUDIO_SINK@"]).unwrap_or_default();
    wpctl_out.to_uppercase().contains("MUTED")
}

fn get_uptime() -> String {
    let raw = std::fs::read_to_string("/proc/uptime").unwrap_or_default();
    let seconds = raw
        .split_whitespace()
        .next()
        .and_then(|s| s.parse::<f64>().ok())
        .map(|s| s as u64)
        .unwrap_or(0);

    let days = seconds / 86400;
    let hours = (seconds % 86400) / 3600;
    let minutes = (seconds % 3600) / 60;

    let mut parts = Vec::new();
    if days > 0 {
        parts.push(format!("{}d", days));
    }
    if hours > 0 {
        parts.push(format!("{}h", hours));
    }
    if minutes > 0 || parts.is_empty() {
        parts.push(format!("{}m", minutes));
    }

    format!("UP {}", parts.join(" ").to_uppercase())
}

fn main() {
    let active_raw = run_cmd("makoctl", &["list", "-j"]).unwrap_or_default();
    let history_raw = run_cmd("makoctl", &["history", "-j"]).unwrap_or_default();

    let status = NotifStatus {
        active: parse_items(&active_raw),
        history: parse_items(&history_raw),
        bt_enabled: is_bluetooth_enabled(),
        wifi_enabled: is_wifi_enabled(),
        audio_muted: is_audio_muted(),
        uptime: get_uptime(),
    };
    print_json(&status);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_flat_mako_array() {
        let items = parse_items(
            r#"[{"id":7,"app-name":"Mail","summary":"Hello","body":"World","urgency":"critical","app-icon":"mail"}]"#,
        );
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, 7);
        assert_eq!(items[0].app_name, "Mail");
        assert_eq!(items[0].urgency, "critical");
    }

    #[test]
    fn parses_wrapped_nested_notifications() {
        let items = parse_items(
            r#"{"data":[[{"id":1,"app_name":"System","summary":"A","urgency":0}]],"ignored":true}"#,
        );
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].summary, "A");
        assert_eq!(items[0].urgency, "low");
    }
}
