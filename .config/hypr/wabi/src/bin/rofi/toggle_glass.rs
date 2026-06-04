use std::env;
use std::fs;
use std::process::Command;
use std::thread;
use std::time::Duration;

fn main() {
    let state_file = "/tmp/quickshell_glass_state";
    let current_state = fs::read_to_string(state_file)
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "true".to_string());

    let home = env::var("HOME").unwrap_or_default();
    let waybar_css = format!("{}/.config/waybar/style.css", home);
    let rofi_theme = format!("{}/.config/rofi/theme.rasi", home);
    let mako_config = format!("{}/.config/mako/config", home);

    let (new_state, opacity, inactive_opacity, blur, osd_status, osd_color) =
        if current_state == "true" {
            ("false", "1.0", "1.0", "false", "Off", "bad")
        } else {
            ("true", "0.85", "0.75", "true", "On", "good")
        };

    if let Ok(content) = fs::read_to_string(&waybar_css) {
        let updated = if new_state == "false" {
            content.replace(
                "background-color: alpha(@bg0, 0.75);",
                "background-color: @bg0;",
            )
        } else {
            content.replace(
                "background-color: @bg0;",
                "background-color: alpha(@bg0, 0.75);",
            )
        };
        let _ = fs::write(&waybar_css, updated);
    }

    if let Ok(content) = fs::read_to_string(&rofi_theme) {
        let updated = if new_state == "false" {
            content.replace("bg0:     #1d202180;", "bg0:     #1d2021;")
        } else {
            content.replace("bg0:     #1d2021;", "bg0:     #1d202180;")
        };
        let _ = fs::write(&rofi_theme, updated);
    }

    if let Ok(content) = fs::read_to_string(&mako_config) {
        let updated = if new_state == "false" {
            content.replace("background-color=#1d202180", "background-color=#1d2021")
        } else {
            content.replace("background-color=#1d2021", "background-color=#1d202180")
        };
        let _ = fs::write(&mako_config, updated);
    }

    let _ = Command::new("makoctl").arg("reload").status();

    let hypr_eval = format!(
        "hl.config({{ decoration = {{ active_opacity = {}, inactive_opacity = {}, blur = {{ enabled = {} }} }} }})",
        opacity, inactive_opacity, blur
    );
    let _ = Command::new("hyprctl").args(["eval", &hypr_eval]).status();

    let _ = fs::write(state_file, new_state);

    let osdctl = format!("{}/.config/quickshell/osd/bin/osdctl", home);
    let _ = Command::new(&osdctl)
        .args(["show", &format!("Glass: {}", osd_status), osd_color, "1200"])
        .status();

    let _ = Command::new("pkill").args(["-x", "waybar"]).status();
    thread::sleep(Duration::from_millis(100));
    let _ = Command::new("waybar")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();
}
