use std::fs;
use std::path::Path;
use std::process::Command;

fn main() {
    let caffeine_flag = Path::new("/tmp/caffeine-mode");
    let caffeine_was_running = Path::new("/tmp/caffeine-was-running");

    if caffeine_flag.exists() {
        let _ = fs::remove_file(caffeine_flag);

        let _ = Command::new("pkill")
            .args(["-f", "systemd-inhibit.*caffeine"])
            .status();

        if !caffeine_was_running.exists() {
            let _ = Command::new("hypridle").spawn();
        }
        let _ = fs::remove_file(caffeine_was_running);

        let home = std::env::var("HOME").unwrap_or_default();
        let osdctl = format!("{}/.config/quickshell/osd/bin/osdctl", home);
        let _ = Command::new(osdctl)
            .args(["show", "caffeine off", "info", "1200"])
            .status();
    } else {
        let pidof_hypridle = Command::new("pidof").arg("hypridle").output();
        let hypridle_running = pidof_hypridle.map(|o| o.status.success()).unwrap_or(false);

        if hypridle_running {
            let _ = fs::File::create(caffeine_was_running);
            let _ = Command::new("pkill").arg("hypridle").status();
        }

        if let Ok(child) = Command::new("systemd-inhibit")
            .args([
                "--what=idle:sleep",
                "--who=caffeine",
                "--why=Caffeine mode",
                "sleep",
                "infinity",
            ])
            .spawn()
        {
            let pid = child.id();
            let _ = fs::write(caffeine_flag, pid.to_string());
        }

        let home = std::env::var("HOME").unwrap_or_default();
        let osdctl = format!("{}/.config/quickshell/osd/bin/osdctl", home);
        let _ = Command::new(osdctl)
            .args(["show", "caffeine on", "good", "1200"])
            .status();
    }
}
