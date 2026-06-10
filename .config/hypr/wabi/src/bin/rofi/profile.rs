use std::env;
use std::io::{self, Write};
use std::process::Command;

fn get_current_profile() -> String {
    let out = Command::new("asusctl").args(["profile", "get"]).output();
    if let Ok(o) = out
        && o.status.success()
    {
        let stdout_str = String::from_utf8_lossy(&o.stdout);
        for line in stdout_str.lines() {
            if line.contains("Active profile") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    return parts[2].trim().to_string();
                }
            }
        }
    }
    String::new()
}

fn main() {
    let current_profile = get_current_profile();

    if let Ok(rofi_retv) = env::var("ROFI_RETV")
        && rofi_retv == "1"
    {
        if let Ok(rofi_info) = env::var("ROFI_INFO") {
            match rofi_info.as_str() {
                "Quiet" | "Balanced" | "Performance" => {
                    let _ = Command::new("asusctl")
                        .args(["profile", "set", &rofi_info])
                        .status();
                    let home = env::var("HOME").unwrap_or_default();
                    let osdctl = format!("{}/.config/quickshell/osd/bin/osdctl", home);
                    let _ = Command::new(osdctl)
                        .args([
                            "show",
                            &format!("profile: {}", rofi_info.to_lowercase()),
                            "good",
                            "1500",
                        ])
                        .status();
                }
                _ => {}
            }
        }
        std::process::exit(0);
    }

    for p in &["Quiet", "Balanced", "Performance"] {
        if *p == current_profile {
            println!("* {}\0info\x1f{}", p, p);
        } else {
            println!("  {}\0info\x1f{}", p, p);
        }
    }

    println!("\0message\x1f{}", current_profile);
    let _ = io::stdout().flush();
}
