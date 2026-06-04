use serde_json::Value;
use std::env;
use std::io::{self, Write};
use std::process::Command;

fn get_field(item: &Value, key: &str) -> String {
    let k_under = key.replace('-', "_");
    let k_dash = key.replace('_', "-");

    if let Some(val) = item
        .get(key)
        .or_else(|| item.get(&k_under))
        .or_else(|| item.get(&k_dash))
    {
        if let Some(data) = val.get("data") {
            if let Some(s) = data.as_str() {
                return s.to_string();
            }
            if let Some(i) = data.as_i64() {
                return i.to_string();
            }
        }
        if let Some(s) = val.as_str() {
            return s.to_string();
        }
        if let Some(i) = val.as_i64() {
            return i.to_string();
        }
    }
    String::new()
}

fn shorten(text: &str) -> String {
    let text = text.replace('\n', " ");
    let text = text.replace('\t', " ");
    let mut result = String::new();
    let mut last_was_space = false;
    for c in text.chars() {
        if c == ' ' {
            if !last_was_space {
                result.push(' ');
                last_was_space = true;
            }
        } else {
            result.push(c);
            last_was_space = false;
        }
    }
    result
}

fn emit_items(source: &str, tag: &str, json_str: &str) {
    if let Ok(v) = serde_json::from_str::<Value>(json_str)
        && let Some(arr) = v.as_array() {
            for item in arr {
                let id = get_field(item, "id");
                let mut app = get_field(item, "app-name");
                if app.is_empty() {
                    app = "mako".to_string();
                }
                let mut summary = get_field(item, "summary");
                if summary.is_empty() {
                    summary = get_field(item, "body");
                }
                if summary.is_empty() {
                    summary = "(no summary)".to_string();
                }
                let summary_short = shorten(&summary);
                if source == "active" {
                    println!(
                        "[{}] {} — {}\0info\x1fdismiss:{}",
                        tag, app, summary_short, id
                    );
                } else {
                    println!(
                        "[{}] {} — {}\0info\x1frestore:{}",
                        tag, app, summary_short, id
                    );
                }
            }
        }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() > 1 {
        if let Ok(rofi_info) = env::var("ROFI_INFO")
            && !rofi_info.is_empty() {
                if rofi_info.starts_with("dismiss:") {
                    let id = rofi_info.trim_start_matches("dismiss:");
                    let _ = Command::new("makoctl").args(["dismiss", "-n", id]).status();
                } else if rofi_info == "restore" || rofi_info.starts_with("restore:") {
                    let _ = Command::new("makoctl").arg("restore").status();
                } else if rofi_info == "clear-all" {
                    let _ = Command::new("makoctl").args(["dismiss", "-a"]).status();
                }
            }
        std::process::exit(0);
    }

    // Active
    let active_out = Command::new("makoctl").args(["list", "-j"]).output();
    if let Ok(out) = active_out
        && out.status.success() {
            let json_str = String::from_utf8_lossy(&out.stdout);
            emit_items("active", "live", &json_str);
        }

    // History
    let history_out = Command::new("makoctl").args(["history", "-j"]).output();
    if let Ok(out) = history_out
        && out.status.success() {
            let json_str = String::from_utf8_lossy(&out.stdout);
            emit_items("history", "hist", &json_str);
        }

    println!("clear all\0info\x1fclear-all");
    println!("\0message\x1fnotifications");
    let _ = io::stdout().flush();
}
