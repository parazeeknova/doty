use std::env;
use std::fs;
use std::process::Command;

const TMPFS_STATE: &str = "/tmp/quickshell_waybar_state";

fn persistent_state() -> String {
    let home = env::var("HOME").unwrap_or_default();
    format!("{}/.cache/quickshell/waybar_state", home)
}

fn main() {
    let home = env::var("HOME").unwrap_or_default();
    let _ = fs::create_dir_all(format!("{}/.cache/quickshell", home));

    let pstate = persistent_state();
    let current_state = fs::read_to_string(&pstate)
        .or_else(|_| fs::read_to_string(TMPFS_STATE))
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "true".to_string());

    let new_state = if current_state == "true" {
        "false"
    } else {
        "true"
    };
    let _ = fs::write(&pstate, new_state);
    let _ = fs::write(TMPFS_STATE, new_state);

    let is_running = Command::new("pgrep")
        .args(["-x", "waybar"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    if is_running {
        let _ = Command::new("pkill")
            .args(["-USR1", "-x", "waybar"])
            .status();
    } else if new_state == "true" {
        let _ = Command::new("uwsm").args(["app", "--", "waybar"]).spawn();
    }
}
