use std::fs;
use std::path::Path;
use std::process::Command;

fn main() {
    let home = std::env::var("HOME").unwrap_or_default();
    let cache_dir = Path::new(&home).join(".cache");
    let caffeine_flag = cache_dir.join("caffeine-active");

    let args: Vec<String> = std::env::args().collect();
    let is_restore = args.len() > 1 && args[1] == "restore";

    if is_restore {
        if caffeine_flag.exists() {
            // Ensure systemd-inhibit is running
            let pgrep = Command::new("pgrep")
                .args(["-f", "systemd-inhibit.*caffeine"])
                .output();
            let already_running = pgrep.map(|o| o.status.success()).unwrap_or(false);
            if !already_running {
                let _ = Command::new("pkill").arg("hypridle").status();
                let _ = Command::new("systemd-inhibit")
                    .args([
                        "--what=idle:sleep",
                        "--who=caffeine",
                        "--why=Caffeine mode",
                        "sleep",
                        "infinity",
                    ])
                    .spawn();
            }
        } else {
            // Ensure hypridle is running
            let pidof_hypridle = Command::new("pidof").arg("hypridle").output();
            let hypridle_running = pidof_hypridle.map(|o| o.status.success()).unwrap_or(false);
            if !hypridle_running {
                let _ = Command::new("uwsm")
                    .args(["app", "--", "hypridle"])
                    .spawn();
            }
        }
        return;
    }

    // Toggle mode
    if caffeine_flag.exists() {
        let _ = fs::remove_file(&caffeine_flag);

        let _ = Command::new("pkill")
            .args(["-f", "systemd-inhibit.*caffeine"])
            .status();

        // Start hypridle back up if not running
        let pidof_hypridle = Command::new("pidof").arg("hypridle").output();
        let hypridle_running = pidof_hypridle.map(|o| o.status.success()).unwrap_or(false);
        if !hypridle_running {
            let _ = Command::new("uwsm")
                .args(["app", "--", "hypridle"])
                .spawn();
        }

        let osdctl = format!("{}/.config/quickshell/osd/bin/osdctl", home);
        let _ = Command::new(osdctl)
            .args(["show", "caffeine off", "info", "1200"])
            .status();
    } else {
        // Create the flag file to persist the state
        let _ = fs::File::create(&caffeine_flag);

        let pidof_hypridle = Command::new("pidof").arg("hypridle").output();
        let hypridle_running = pidof_hypridle.map(|o| o.status.success()).unwrap_or(false);
        if hypridle_running {
            let _ = Command::new("pkill").arg("hypridle").status();
        }

        let _ = Command::new("systemd-inhibit")
            .args([
                "--what=idle:sleep",
                "--who=caffeine",
                "--why=Caffeine mode",
                "sleep",
                "infinity",
            ])
            .spawn();

        let osdctl = format!("{}/.config/quickshell/osd/bin/osdctl", home);
        let _ = Command::new(osdctl)
            .args(["show", "caffeine on", "good", "1200"])
            .status();
    }
}
