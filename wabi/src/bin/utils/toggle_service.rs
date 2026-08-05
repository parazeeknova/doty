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

fn run_systemctl(service: &str, user: bool, currently_active: bool) {
    let action = if currently_active { "stop" } else { "start" };
    let mut cmd = Command::new("systemctl");
    if user {
        cmd.arg("--user");
    }
    cmd.args([action, service]);
    let _ = cmd.status();
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
