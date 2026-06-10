use std::env;
use std::os::unix::net::UnixStream;
use std::path::Path;
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

fn is_daemon_responsive(socket_path: &str) -> bool {
    Path::new(socket_path).exists() && UnixStream::connect(socket_path).is_ok()
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

fn send_notification(restarted: &[String]) {
    if restarted.is_empty() {
        return;
    }

    let message = if restarted.len() == 1 {
        format!("Restarted: {}", restarted[0])
    } else {
        format!(
            "Restarted {} daemons:\n{}",
            restarted.len(),
            restarted.join(", ")
        )
    };

    let _ = Command::new("notify-send")
        .arg("-i")
        .arg("dialog-warning")
        .arg("-t")
        .arg("5000")
        .arg("Daemon Watchdog")
        .arg(&message)
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
            start_command:
                "uwsm app -- ~/.config/quickshell/wallpaper_switcher/wallpaper_thumb_watcher",
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

    let mut restarted = Vec::new();

    for daemon in daemons {
        // For daemons with IPC sockets, check responsiveness instead of just process existence
        let needs_restart = if let Some(socket_name) = daemon.ipc_socket {
            let socket_path = format!("{}/{}", runtime_dir, socket_name);
            !is_daemon_responsive(&socket_path)
        } else {
            !is_process_running(daemon.process_name)
        };

        if needs_restart {
            eprintln!("{} not running, restarting...", daemon.name);
            if start_daemon(&daemon) {
                restarted.push(daemon.name.to_string());
                eprintln!("{} restarted successfully", daemon.name);
            } else {
                eprintln!("Failed to restart {}", daemon.name);
            }
        }
    }

    send_notification(&restarted);

    if !restarted.is_empty() {
        println!("Restarted {} daemon(s)", restarted.len());
    }
}
