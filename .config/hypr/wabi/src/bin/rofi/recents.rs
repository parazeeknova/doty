use serde_json::Value;
use std::env;
use std::io::{self, Write};
use std::process::Command;

fn to_roman(mut num: i32) -> String {
    let mut roman = String::new();
    let values = [10, 9, 5, 4, 1];
    let symbols = ["x", "ix", "v", "iv", "i"];

    for i in 0..values.len() {
        while num >= values[i] {
            roman.push_str(symbols[i]);
            num -= values[i];
        }
    }
    roman
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() > 1 && !args[1].is_empty() {
        if let Ok(rofi_info) = env::var("ROFI_INFO") {
            if rofi_info.starts_with("ws:") {
                let ws = rofi_info.trim_start_matches("ws:");
                let _ = Command::new("hyprctl")
                    .args(["dispatch", &format!("hl.dsp.focus({{workspace={}}})", ws)])
                    .status();
            }
        }
        std::process::exit(0);
    }

    let clients_out = Command::new("hyprctl").args(["clients", "-j"]).output();

    if let Ok(out) = clients_out {
        if out.status.success() {
            let stdout_str = String::from_utf8_lossy(&out.stdout);
            if let Ok(Value::Array(clients)) = serde_json::from_str::<Value>(&stdout_str) {
                for client in clients {
                    if let Some(title) = client.get("title").and_then(|t| t.as_str()) {
                        if !title.is_empty() {
                            if let Some(ws_id) = client
                                .get("workspace")
                                .and_then(|w| w.get("id"))
                                .and_then(|id| id.as_i64())
                            {
                                let roman = to_roman(ws_id as i32);
                                print!("[{}] {}\0info\x1fws:{}\n", roman, title, ws_id);
                            }
                        }
                    }
                }
            }
        }
    }

    print!("\0message\x1frecents\n");
    let _ = io::stdout().flush();
}
