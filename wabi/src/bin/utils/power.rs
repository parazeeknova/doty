use std::env;
use std::process::Command;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: wabi_power <lock|sleep|reboot|poweroff|logout>");
        std::process::exit(1);
    }

    let action = args[1].as_str();

    let cmd = match action {
        "lock" => "hyprlock -c ~/.config/hypr/hyprlock.conf",
        "sleep" => "systemctl suspend",
        "reboot" => "systemctl reboot",
        "poweroff" => "systemctl poweroff",
        "logout" => {
            "if command -v uwsm >/dev/null 2>&1 && uwsm check is-active; then uwsm stop; else hyprctl dispatch exit || pkill -x Hyprland; fi"
        }
        _ => {
            eprintln!("Unknown action: {}", action);
            std::process::exit(1);
        }
    };

    let status = Command::new("sh").args(["-c", cmd]).status();

    match status {
        Ok(s) if s.success() => {}
        Ok(s) => {
            eprintln!("Command failed with exit status: {:?}", s);
            std::process::exit(1);
        }
        Err(e) => {
            eprintln!("Failed to execute command: {}", e);
            std::process::exit(1);
        }
    }
}
