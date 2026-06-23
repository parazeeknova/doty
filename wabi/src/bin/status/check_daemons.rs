use std::env;
use std::process::Command;

struct Daemon {
    name: &'static str,
    process_name: &'static str,
    start_command: &'static str,
    ipc_socket: Option<&'static str>,
}

fn is_process_running(process_name: &str) -> bool {
    Command::new("pgrep")
        .arg("-f")
        .arg(process_name)
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

fn start_daemon(daemon: &Daemon) -> bool {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());

    // Replace ~ with actual home directory
    let command = daemon.start_command.replace("~", &home);

    // Execute via bash to handle complex commands
    Command::new("bash")
        .arg("-c")
        .arg(&command)
        .spawn()
        .map(|_| true)
        .unwrap_or(false)
}

fn send_notification(started: &[String], restarted: &[String]) {
    if started.is_empty() && restarted.is_empty() {
        return;
    }

    let mut parts = Vec::new();
    if !started.is_empty() {
        if started.len() == 1 {
            parts.push(format!("Started: {}", started[0]));
        } else {
            parts.push(format!(
                "Started {} daemons:\n{}",
                started.len(),
                started.join(", ")
            ));
        }
    }
    if !restarted.is_empty() {
        if restarted.len() == 1 {
            parts.push(format!("Restarted: {}", restarted[0]));
        } else {
            parts.push(format!(
                "Restarted {} daemons:\n{}",
                restarted.len(),
                restarted.join(", ")
            ));
        }
    }

    let _ = Command::new("notify-send")
        .arg("-i")
        .arg("dialog-information")
        .arg("-t")
        .arg("5000")
        .arg("Daemon Watchdog")
        .arg(parts.join("\n"))
        .status();
}

fn main() {
    let runtime_dir = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".to_string());

    let daemons = vec![
        Daemon {
            name: "Battery Daemon",
            process_name: "battery_daemon",
            start_command: "uwsm app -- ~/.config/quickshell/battery_popup/battery_daemon",
            ipc_socket: None,
        },
        Daemon {
            name: "Screentime Daemon",
            process_name: "screentime_daemon",
            start_command: "uwsm app -- ~/.local/bin/screentime_daemon",
            ipc_socket: Some("wabi_screentime.sock"),
        },
        Daemon {
            name: "Wallpaper Watcher",
            process_name: "wallpaper_thumb_watcher",
            start_command: "uwsm app -- ~/.config/quickshell/wallpaper_switcher/wallpaper_thumb_watcher",
            ipc_socket: None,
        },
        Daemon {
            name: "Clipboard (text)",
            process_name: "wl-paste --type text --watch cliphist store",
            start_command: "uwsm app -- wl-paste --type text --watch cliphist store",
            ipc_socket: None,
        },
        Daemon {
            name: "Clipboard (image)",
            process_name: "wl-paste --type image --watch cliphist store",
            start_command: "uwsm app -- wl-paste --type image --watch cliphist store",
            ipc_socket: None,
        },
        Daemon {
            name: "Waybar",
            process_name: "waybar",
            start_command: "uwsm app -- waybar",
            ipc_socket: None,
        },
        Daemon {
            name: "Hypridle",
            process_name: "hypridle",
            start_command: "uwsm app -- hypridle",
            ipc_socket: None,
        },
        Daemon {
            name: "Hyprsunset",
            process_name: "hyprsunset",
            start_command: "uwsm app -- hyprsunset",
            ipc_socket: None,
        },
        Daemon {
            name: "Pyprland",
            process_name: "pypr",
            start_command: "uwsm app -- pypr",
            ipc_socket: None,
        },
    ];

    let mut started = Vec::new();

    for daemon in daemons {
        let needs_start = if let Some(socket_name) = daemon.ipc_socket {
            if is_process_running(daemon.process_name) {
                false
            } else {
                let socket_path = format!("{}/{}", runtime_dir, socket_name);
                let _ = std::fs::remove_file(&socket_path);
                true
            }
        } else {
            !is_process_running(daemon.process_name)
        };

        if needs_start {
            eprintln!("{} not running, starting...", daemon.name);
            if start_daemon(&daemon) {
                started.push(daemon.name.to_string());
                eprintln!("{} started successfully", daemon.name);
            } else {
                eprintln!("Failed to start {}", daemon.name);
            }
        }
    }

    send_notification(&started, &[]);

    if !started.is_empty() {
        println!("Started {} daemon(s)", started.len());
    }
}
