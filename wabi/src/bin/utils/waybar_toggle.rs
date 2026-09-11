use std::env;
use std::fs;
use std::process::Command;

const TMPFS_STATE: &str = "/tmp/quickshell_waybar_state";

fn persistent_state() -> String {
    let home = env::var("HOME").unwrap_or_default();
    format!("{}/.cache/quickshell/waybar_state", home)
}

fn is_waybar_running() -> bool {
    let is_normal = Command::new("pgrep")
        .args(["-x", "waybar"])
        .stdout(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if is_normal {
        return true;
    }
    Command::new("pgrep")
        .args(["-x", ".waybar-wrapped"])
        .stdout(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
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

    let is_running = is_waybar_running();

    if is_running {
        if new_state == "false" {
            // hiding kills the bar (USR1 toggle only shows/hides; killing
            // keeps things simple and layoutmode respawns the right variant)
            let _ = Command::new("pkill")
                .args(["-KILL", "-x", "waybar"])
                .status();
            let _ = Command::new("pkill")
                .args(["-KILL", "-x", ".waybar-wrapped"])
                .status();
        } else {
            // showing a hidden bar: USR1 unhides it
            let _ = Command::new("pkill")
                .args(["-USR1", "-x", "waybar"])
                .status();
            let _ = Command::new("pkill")
                .args(["-USR1", "-x", ".waybar-wrapped"])
                .status();
        }
    } else if new_state == "true" {
        // launch the variant matching the layout mode (written by layoutmode)
        let variant = fs::read_to_string(format!("{}/.cache/hypr_layout_waybar", home))
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| "left".to_string());
        let (cfg, style) = match variant.as_str() {
            "top" => ("config-top.jsonc", "style-top.css"),
            _ => ("config.jsonc", "style.css"),
        };
        let cfg_path = format!("{}/.config/waybar/{}", home, cfg);
        let style_path = format!("{}/.config/waybar/{}", home, style);
        let _ = Command::new("uwsm")
            .args(["app", "--", "waybar", "-c", &cfg_path, "-s", &style_path])
            .spawn();
    }
}
