use std::env;
use std::fs;
use std::process::Command;

const TMPFS_STATE: &str = "/tmp/quickshell_widgets_state";
const TMPFS_CONFIG: &str = "/tmp/quickshell_widgets_config";
const TMPFS_WAYBAR: &str = "/tmp/quickshell_waybar_state";

fn persistent_state() -> String {
    let home = env::var("HOME").unwrap_or_default();
    format!("{}/.cache/quickshell/widgets_state", home)
}

fn persistent_config() -> String {
    let home = env::var("HOME").unwrap_or_default();
    format!("{}/.cache/quickshell/widgets_config", home)
}

fn persistent_waybar_state() -> String {
    let home = env::var("HOME").unwrap_or_default();
    format!("{}/.cache/quickshell/waybar_state", home)
}

fn get_target_visibility(mode: &str, dynamic_state: &str) -> (bool, bool, bool) {
    if dynamic_state == "false" {
        return (false, false, false);
    }
    match mode {
        "both" => (true, true, true),
        "github" => (true, false, true),
        "workspace" => (false, true, true),
        "none" => (false, false, true),
        _ => (true, true, true), // default/fallback
    }
}

fn run_command_robust(cmd: &str, args: &[&str]) -> std::io::Result<std::process::ExitStatus> {
    match Command::new(cmd).args(args).status() {
        Ok(status) => Ok(status),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => {
            let fallback_path = format!("/run/current-system/sw/bin/{}", cmd);
            Command::new(fallback_path).args(args).status()
        }
        Err(err) => Err(err),
    }
}

fn spawn_command_robust(cmd: &str, args: &[&str]) -> std::io::Result<std::process::Child> {
    match Command::new(cmd).args(args).spawn() {
        Ok(child) => Ok(child),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => {
            let fallback_path = format!("/run/current-system/sw/bin/{}", cmd);
            Command::new(fallback_path).args(args).spawn()
        }
        Err(err) => Err(err),
    }
}

fn is_waybar_running() -> bool {
    // NixOS wraps waybar as `.waybar-wrapped`, so `pgrep -x waybar` never matches.
    // Use `pgrep -f` against the cmdline path instead.
    Command::new("pgrep")
        .args(["-f", "bin/waybar"])
        .stdout(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn kill_waybar() {
    let _ = Command::new("pkill").args(["-f", "bin/waybar"]).status();
}

fn apply_state(github_visible: bool, workspace_visible: bool, waybar_visible: bool) {
    let _ = run_command_robust(
        "quickshell",
        &[
            "-c",
            "github_graph",
            "ipc",
            "call",
            "github_graph",
            if github_visible { "onShow" } else { "onHide" },
        ],
    );
    let _ = run_command_robust(
        "quickshell",
        &[
            "-c",
            "workspace_overview",
            "ipc",
            "call",
            "workspace_overview",
            if workspace_visible {
                "onShow"
            } else {
                "onHide"
            },
        ],
    );

    let pwaybar = persistent_waybar_state();
    if waybar_visible {
        let _ = fs::write(TMPFS_WAYBAR, "true");
        let _ = fs::write(pwaybar, "true");
        if !is_waybar_running() {
            let _ = spawn_command_robust("uwsm", &["app", "--", "waybar"]);
        }
    } else {
        let _ = fs::write(TMPFS_WAYBAR, "false");
        let _ = fs::write(pwaybar, "false");
        kill_waybar();
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    let _ = fs::create_dir_all(
        env::var("HOME")
            .map(|h| format!("{}/.cache/quickshell", h))
            .unwrap_or_default(),
    );

    if args.len() > 1 && args[1] == "restore" {
        let pstate = persistent_state();
        let state = fs::read_to_string(&pstate)
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| "true".to_string());
        let _ = fs::write(TMPFS_STATE, &state);

        let pconfig = persistent_config();
        let mode = fs::read_to_string(&pconfig)
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| "default".to_string());
        let _ = fs::write(TMPFS_CONFIG, &mode);

        let (gh, ws, wb) = get_target_visibility(&mode, &state);
        apply_state(gh, ws, wb);
        return;
    }

    if args.len() > 2 && args[1] == "--set-mode" {
        let mode = args[2].clone();
        let _ = fs::write(persistent_config(), &mode);
        let _ = fs::write(TMPFS_CONFIG, &mode);

        let state = fs::read_to_string(TMPFS_STATE)
            .or_else(|_| fs::read_to_string(persistent_state()))
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| "true".to_string());

        let (gh, ws, wb) = get_target_visibility(&mode, &state);
        apply_state(gh, ws, wb);
        return;
    }

    let mode = fs::read_to_string(TMPFS_CONFIG)
        .or_else(|_| fs::read_to_string(persistent_config()))
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "default".to_string());

    let current = fs::read_to_string(TMPFS_STATE)
        .or_else(|_| fs::read_to_string(persistent_state()))
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "true".to_string());

    let new_state = if current == "true" { "false" } else { "true" };

    let _ = fs::write(persistent_state(), new_state);
    let _ = fs::write(TMPFS_STATE, new_state);

    let (gh, ws, wb) = get_target_visibility(&mode, new_state);
    apply_state(gh, ws, wb);
}
