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
        Ok(out) => String::from_utf8_lossy(&out.stdout).trim() == "active",
        Err(_) => false,
    }
}

fn send_notification(service_label: &str, turning_on: bool) {
    let status_str = if turning_on {
        "Enabled & Started"
    } else {
        "Disabled & Stopped"
    };
    let icon = if turning_on {
        "emblem-default"
    } else {
        "process-stop"
    };
    let _ = Notification::new()
        .summary("Service Manager")
        .body(&format!("{service_label} service is now {status_str}"))
        .icon(icon)
        .timeout(3000)
        .show();
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: toggle_service <suwayomi|llama|adguard>");
        std::process::exit(1);
    }

    let target = args[1].as_str();
    match target {
        "suwayomi" => {
            let active = is_active("suwayomi-server.service", false);
            let action = if active { "disable" } else { "enable" };
            let _ = Command::new("sudo")
                .args(["systemctl", action, "--now", "suwayomi-server.service"])
                .status();
            send_notification("Suwayomi Server", !active);
        }
        "llama" => {
            let active = is_active("llama-server.service", true);
            let action = if active { "disable" } else { "enable" };
            let _ = Command::new("systemctl")
                .args(["--user", action, "--now", "llama-server.service"])
                .status();
            send_notification("llama.cpp Server", !active);
        }
        "adguard" => {
            let active = is_active("adguardhome.service", false);
            let action = if active { "disable" } else { "enable" };
            let _ = Command::new("sudo")
                .args(["systemctl", action, "--now", "adguardhome.service"])
                .status();
            send_notification("AdGuard Home", !active);
        }
        _ => {
            eprintln!("Unknown service: {}", target);
            std::process::exit(1);
        }
    }
}
