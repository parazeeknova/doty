use std::process::Command;
use std::env;

struct Daemon {
    name: &'static str,
    process_name: &'static str,
    start_command: &'static str,
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

fn send_notification(restarted: &[String]) {
    if restarted.is_empty() {
        return;
    }

    let message = if restarted.len() == 1 {
        format!("Restarted: {}", restarted[0])
    } else {
        format!("Restarted {} daemons:\n{}", restarted.len(), restarted.join(", "))
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
    let daemons = vec![
        Daemon {
            name: "Battery Daemon",
            process_name: "battery_daemon",
            start_command: "uwsm app -- ~/.config/quickshell/battery_popup/battery_daemon",
        },
        Daemon {
            name: "Screentime Daemon",
            process_name: "screentime_daemon",
            start_command: "uwsm app -- ~/.local/bin/screentime_daemon",
        },
        Daemon {
            name: "Wallpaper Watcher",
            process_name: "wallpaper_thumb_watcher",
            start_command: "uwsm app -- ~/.config/quickshell/wallpaper_switcher/wallpaper_thumb_watcher",
        },
        Daemon {
            name: "Clipboard (text)",
            process_name: "wl-paste --type text --watch cliphist store",
            start_command: "uwsm app -- wl-paste --type text --watch cliphist store",
        },
        Daemon {
            name: "Clipboard (image)",
            process_name: "wl-paste --type image --watch cliphist store",
            start_command: "uwsm app -- wl-paste --type image --watch cliphist store",
        },
        Daemon {
            name: "Waybar",
            process_name: "waybar",
            start_command: "uwsm app -- waybar",
        },
        Daemon {
            name: "Hypridle",
            process_name: "hypridle",
            start_command: "uwsm app -- hypridle",
        },
        Daemon {
            name: "Hyprsunset",
            process_name: "hyprsunset",
            start_command: "uwsm app -- hyprsunset",
        },
        Daemon {
            name: "Pyprland",
            process_name: "pypr",
            start_command: "uwsm app -- pypr",
        },
    ];

    let mut restarted = Vec::new();

    for daemon in daemons {
        if !is_process_running(daemon.process_name) {
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
