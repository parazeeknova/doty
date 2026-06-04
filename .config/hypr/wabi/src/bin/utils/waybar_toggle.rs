use std::process::Command;

fn main() {
    let is_running = Command::new("pgrep")
        .args(["-x", "waybar"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    if is_running {
        let _ = Command::new("pkill")
            .args(["-USR1", "-x", "waybar"])
            .status();
    } else {
        let _ = Command::new("waybar").spawn();
    }
}
