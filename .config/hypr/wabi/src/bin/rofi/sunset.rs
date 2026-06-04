use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::Command;
use std::thread;
use std::time::Duration;

fn get_state_file() -> PathBuf {
    let home = env::var("HOME").unwrap_or_default();
    PathBuf::from(home).join(".config/hypr/sunset.state")
}

fn get_config_file() -> PathBuf {
    let home = env::var("HOME").unwrap_or_default();
    PathBuf::from(home).join(".config/hypr/hyprsunset.conf")
}

fn clear_config() {
    let _ = fs::write(get_config_file(), "");
}

fn write_auto_config() {
    let config_content = r#"profile {
    time = 08:00
    identity = true
}
profile {
    time = 18:00
    temperature = 5000
}
profile {
    time = 22:00
    temperature = 4000
}
profile {
    time = 06:00
    temperature = 5000
}
"#;
    let _ = fs::write(get_config_file(), config_content);
}

fn restart_sunset(args: &[&str]) {
    let _ = Command::new("killall").arg("hyprsunset").status();
    thread::sleep(Duration::from_millis(100));
    let _ = Command::new("hyprsunset").args(args).spawn();
}

fn main() {
    let state_file = get_state_file();
    let current_state = fs::read_to_string(&state_file)
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "Off".to_string());

    let args: Vec<String> = env::args().collect();
    if args.len() > 1 {
        let selection = env::var("ROFI_INFO").unwrap_or_else(|_| args[1].clone());
        let home = env::var("HOME").unwrap_or_default();
        let osdctl = format!("{}/.config/quickshell/osd/bin/osdctl", home);

        match selection.as_str() {
            "off" => {
                clear_config();
                restart_sunset(&["-i"]);
                let _ = fs::write(&state_file, "Off");
                let _ = Command::new(&osdctl)
                    .args(["show", "sunset off", "info", "1200"])
                    .status();
            }
            "sunset" => {
                clear_config();
                restart_sunset(&["-t", "4500"]);
                let _ = fs::write(&state_file, "Sunset");
                let _ = Command::new(&osdctl)
                    .args(["show", "sunset 4500k", "info", "1200"])
                    .status();
            }
            "night" => {
                clear_config();
                restart_sunset(&["-t", "3500"]);
                let _ = fs::write(&state_file, "Night");
                let _ = Command::new(&osdctl)
                    .args(["show", "sunset 3500k", "info", "1200"])
                    .status();
            }
            "midnight" => {
                clear_config();
                restart_sunset(&["-t", "2500"]);
                let _ = fs::write(&state_file, "Midnight");
                let _ = Command::new(&osdctl)
                    .args(["show", "sunset 2500k", "info", "1200"])
                    .status();
            }
            "default" => {
                clear_config();
                restart_sunset(&["-t", "6000"]);
                let _ = fs::write(&state_file, "Default");
                let _ = Command::new(&osdctl)
                    .args(["show", "sunset 6000k", "info", "1200"])
                    .status();
            }
            "auto" => {
                write_auto_config();
                restart_sunset(&[]);
                let _ = fs::write(&state_file, "Auto");

                let out = Command::new("date").arg("+%H").output();
                let current_hour = out
                    .map(|o| {
                        String::from_utf8_lossy(&o.stdout)
                            .trim()
                            .parse::<i32>()
                            .unwrap_or(12)
                    })
                    .unwrap_or(12);

                let temp = if !(6..22).contains(&current_hour) {
                    "auto: 4000k"
                } else if (18..22).contains(&current_hour) || (6..8).contains(&current_hour) {
                    "auto: 5000k"
                } else {
                    "auto: off"
                };
                let _ = Command::new(&osdctl)
                    .args(["show", &format!("sunset {}", temp), "info", "1200"])
                    .status();
            }
            s if s.chars().all(|c| c.is_ascii_digit()) => {
                clear_config();
                restart_sunset(&["-t", s]);
                let _ = fs::write(&state_file, s);
                let _ = Command::new(&osdctl)
                    .args(["show", &format!("sunset {}k", s), "info", "1200"])
                    .status();
            }
            _ => {}
        }
        std::process::exit(0);
    }

    let options = [
        ("Auto", "auto"),
        ("Off", "off"),
        ("Default (6000K)", "default"),
        ("Sunset (4500K)", "sunset"),
        ("Night (3500K)", "night"),
        ("Midnight (2500K)", "midnight"),
    ];

    for (name, key) in &options {
        let clean_name = name.split(" (").next().unwrap_or(name);
        if clean_name == current_state || *name == current_state {
            println!("* {}\0info\x1f{}", name, key);
        } else {
            println!("  {}\0info\x1f{}", name, key);
        }
    }

    println!("\0message\x1fsunset");
    let _ = io::stdout().flush();
}
