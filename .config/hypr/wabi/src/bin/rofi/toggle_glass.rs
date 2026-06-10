use std::env;
use std::fs;
use std::process::Command;
use std::thread;
use std::time::Duration;

fn toggle_hex_alpha_lines(content: &str, key: &str, line_suffix: &str, want_alpha: bool) -> String {
    content
        .lines()
        .map(|line| {
            let trimmed = line.trim_start();
            if !trimmed.starts_with(key) {
                return line.to_string();
            }
            let hash_idx = match line.find('#') {
                Some(i) => i,
                None => return line.to_string(),
            };
            let after_hash = &line[hash_idx + 1..];
            let hex_end = after_hash
                .find(|c: char| !c.is_ascii_hexdigit())
                .unwrap_or(after_hash.len());
            let hex = &after_hash[..hex_end];
            if hex.len() != 6 && hex.len() != 8 {
                return line.to_string();
            }
            let base = &hex[..6];
            let new_hex = if want_alpha {
                format!("{}80", base)
            } else {
                base.to_string()
            };
            let tail = &after_hash[hex_end..];
            let mut rebuilt = format!("{}#{}{}", &line[..hash_idx], new_hex, tail);
            if !line_suffix.is_empty() && !rebuilt.trim_end().ends_with(line_suffix) {
                rebuilt.push_str(line_suffix);
            }
            rebuilt
        })
        .collect::<Vec<_>>()
        .join("\n")
        + if content.ends_with('\n') { "\n" } else { "" }
}

fn apply_glass_state(home: &str, want_alpha: bool, opacity: &str, inactive_opacity: &str, blur: &str) {
    let waybar_css = format!("{home}/.config/waybar/style.css");
    let rofi_colors = format!("{home}/.config/rofi/colors.rasi");
    let mako_config = format!("{home}/.config/mako/config");

    if let Ok(content) = fs::read_to_string(&waybar_css) {
        let updated = if want_alpha {
            content.replace(
                "background-color: @bg0;",
                "background-color: alpha(@bg0, 0.75);",
            )
        } else {
            content.replace(
                "background-color: alpha(@bg0, 0.75);",
                "background-color: @bg0;",
            )
        };
        let _ = fs::write(&waybar_css, updated);
    }

    if let Ok(content) = fs::read_to_string(&rofi_colors) {
        let updated = toggle_hex_alpha_lines(&content, "bg0:", ";", want_alpha);
        let _ = fs::write(&rofi_colors, updated);
    }

    if let Ok(content) = fs::read_to_string(&mako_config) {
        let updated = toggle_hex_alpha_lines(&content, "background-color=", "", want_alpha);
        let _ = fs::write(&mako_config, updated);
    }

    let _ = Command::new("makoctl").arg("reload").status();

    let hypr_eval = format!(
        "hl.config({{ decoration = {{ active_opacity = {opacity}, inactive_opacity = {inactive_opacity}, blur = {{ enabled = {blur} }} }} }})"
    );
    let _ = Command::new("hyprctl").args(["eval", &hypr_eval]).status();
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let home = env::var("HOME").unwrap_or_default();
    let persistent_state = format!("{home}/.cache/quickshell/glass_state");
    let tmpfs_state = "/tmp/quickshell_glass_state".to_string();

    let _ = fs::create_dir_all(format!("{home}/.cache/quickshell"));

    let is_restore = args.len() > 1 && args[1] == "restore";

    let state = fs::read_to_string(&persistent_state)
        .or_else(|_| fs::read_to_string(&tmpfs_state))
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "true".to_string());

    let (new_state, opacity, inactive_opacity, blur) = if state == "true" {
        if is_restore {
            ("true", "0.85", "0.75", "true")
        } else {
            ("false", "1.0", "1.0", "false")
        }
    } else {
        if is_restore {
            ("false", "1.0", "1.0", "false")
        } else {
            ("true", "0.85", "0.75", "true")
        }
    };

    apply_glass_state(&home, new_state == "true", opacity, inactive_opacity, blur);

    let _ = fs::write(&persistent_state, new_state);
    let _ = fs::write(&tmpfs_state, new_state);

    if !is_restore {
        let osd_status = if new_state == "true" { "On" } else { "Off" };
        let osd_color = if new_state == "true" { "good" } else { "bad" };
        let osdctl = format!("{home}/.config/quickshell/osd/bin/osdctl");
        let _ = Command::new(&osdctl)
            .args(["show", &format!("Glass: {osd_status}"), osd_color, "1200"])
            .status();

        let widgets_state = fs::read_to_string("/tmp/quickshell_widgets_state")
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| "true".to_string());

        let _ = Command::new("pkill").args(["-x", "waybar"]).status();
        if widgets_state != "false" {
            thread::sleep(Duration::from_millis(100));
            let _ = Command::new("waybar")
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn();
        }
    }
}
