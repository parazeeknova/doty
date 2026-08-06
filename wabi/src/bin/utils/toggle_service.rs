use notify_rust::Notification;
use std::env;
use std::process::Command;

fn is_active(service: &str, user: bool) -> bool {
    let mut cmd = Command::new("systemctl");
    if user {
        cmd.arg("--user");
    }
    cmd.args(["is-active", service]);
    match cmd.output() {
        Ok(out) => {
            let state = String::from_utf8_lossy(&out.stdout);
            matches!(
                state.trim(),
                "active" | "activating" | "deactivating" | "reloading"
            )
        }
        Err(_) => false,
    }
}

fn run_systemctl(service: &str, user: bool, currently_active: bool) {
    let action = if currently_active { "stop" } else { "start" };
    let mut cmd = Command::new("systemctl");
    if user {
        cmd.arg("--user");
    }
    cmd.args([action, service]);
    let _ = cmd.status();

    // Persist the choice across reboots for USER services only. On NixOS,
    // system services are boot-enabled declaratively via the read-only
    // /etc/systemd/system (flake-managed), so their enable state can't be
    // changed at runtime — the stop/start above is all that's possible.
    if user {
        set_user_enabled(service, !currently_active);
    }
}

fn set_user_enabled(service: &str, enable: bool) {
    // Persist boot-enable state for user services by managing the
    // default.target.wants symlink directly. On NixOS, `systemctl --user
    // enable/disable` also removes the unit-file link (a store symlink),
    // leaving the unit "not-found" and un-enableable. Touching only the
    // wants link keeps the unit intact while controlling autostart.
    let wants_dir = std::env::var("HOME")
        .map(std::path::PathBuf::from)
        .unwrap_or_default()
        .join(".config/systemd/user/default.target.wants");
    let link = wants_dir.join(service);

    if enable {
        if link.exists() {
            return;
        }
        // Resolve the unit's real path so the wants link stays valid.
        if let Ok(out) = Command::new("systemctl")
            .args(["--user", "show", service, "-p", "FragmentPath", "--value"])
            .output()
        {
            let unit = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if !unit.is_empty() && std::path::Path::new(&unit).exists() {
                let _ = std::fs::create_dir_all(&wants_dir);
                let _ = std::os::unix::fs::symlink(&unit, &link);
                let _ = Command::new("systemctl")
                    .args(["--user", "daemon-reload"])
                    .status();
            }
        }
    } else {
        let _ = std::fs::remove_file(&link);
        let _ = Command::new("systemctl")
            .args(["--user", "daemon-reload"])
            .status();
    }
}

fn send_notification(service_label: &str, turning_on: bool) {
    let status_str = if turning_on { "Started" } else { "Stopped" };
    let icon = if turning_on {
        "emblem-default"
    } else {
        "process-stop"
    };
    let _ = Notification::new()
        .summary("Service Manager")
        .body(&format!("{service_label} — {status_str}"))
        .icon(icon)
        .timeout(3000)
        .show();
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: toggle_service <suwayomi|llama|adguard>");
        eprintln!("  User services (llama) persist stop/start across reboot;");
        eprintln!("  system services (suwayomi/adguard) are runtime-only on NixOS.");
        std::process::exit(1);
    }

    let target = args[1].as_str();
    match target {
        "suwayomi" => {
            let active = is_active("suwayomi-server.service", false);
            run_systemctl("suwayomi-server.service", false, active);
            send_notification("Suwayomi Server", !active);
        }
        "llama" => {
            let active = is_active("llama-server.service", true);
            run_systemctl("llama-server.service", true, active);
            send_notification("llama.cpp Server", !active);
        }
        "adguard" => {
            let active = is_active("adguardhome.service", false);
            run_systemctl("adguardhome.service", false, active);
            send_notification("AdGuard Home", !active);
        }
        _ => {
            eprintln!("Unknown service: {}", target);
            std::process::exit(1);
        }
    }
}
