use std::env;
use std::io::{self, Write};
use std::process::Command;

fn main() {
    if let Ok(rofi_retv) = env::var("ROFI_RETV") {
        if rofi_retv == "1" {
            if let Ok(rofi_info) = env::var("ROFI_INFO") {
                match rofi_info.as_str() {
                    "poweroff" => {
                        let _ = Command::new("systemctl").arg("poweroff").status();
                    }
                    "reboot" => {
                        let _ = Command::new("systemctl").arg("reboot").status();
                    }
                    "logout" => {
                        let uwsm_check = Command::new("uwsm")
                            .arg("check")
                            .status()
                            .map(|s| s.success())
                            .unwrap_or(false);
                        if uwsm_check {
                            let _ = Command::new("uwsm").arg("stop").status();
                        } else {
                            if Command::new("hyprctl")
                                .args(["dispatch", "hl.dsp.exit()"])
                                .status()
                                .is_err()
                            {
                                let _ = Command::new("pkill").args(["-x", "Hyprland"]).status();
                            }
                        }
                    }
                    "sleep" => {
                        let _ = Command::new("systemctl").arg("suspend").status();
                    }
                    "lock" => {
                        let home = env::var("HOME").unwrap_or_default();
                        let lock_conf = format!("{}/.config/hypr/hyprlock.conf", home);
                        let _ = Command::new("hyprlock").args(["-c", &lock_conf]).status();
                    }
                    _ => {}
                }
            }
            std::process::exit(0);
        }
    }

    print!("lock\0info\x1flock\n");
    print!("sleep\0info\x1fsleep\n");
    print!("reboot\0info\x1freboot\n");
    print!("poweroff\0info\x1fpoweroff\n");
    print!("logout\0info\x1flogout\n");
    print!("\0message\x1fpower\n");
    let _ = io::stdout().flush();
}
