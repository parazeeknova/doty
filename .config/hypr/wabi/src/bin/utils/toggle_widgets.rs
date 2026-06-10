use std::env;
use std::fs;
use std::process::Command;

const TMPFS_STATE: &str = "/tmp/quickshell_widgets_state";

fn persistent_state() -> String {
    let home = env::var("HOME").unwrap_or_default();
    format!("{}/.cache/quickshell/widgets_state", home)
}

fn apply_state(state: &str) {
    let ipc_func = if state == "true" { "onShow" } else { "onHide" };

    let _ = Command::new("quickshell")
        .args(["-c", "github_graph", "ipc", "call", "github_graph", ipc_func])
        .status();
    let _ = Command::new("quickshell")
        .args(["-c", "workspace_overview", "ipc", "call", "workspace_overview", ipc_func])
        .status();

    if state == "false" {
        let _ = Command::new("pkill")
            .args(["-x", "waybar"])
            .status();
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() > 1 && args[1] == "restore" {
        let pstate = persistent_state();
        let state = fs::read_to_string(&pstate)
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| "true".to_string());

        let _ = fs::write(TMPFS_STATE, &state);

        if state == "false" {
            apply_state("false");
        }
        return;
    }

    let _ = fs::create_dir_all(
        env::var("HOME")
            .map(|h| format!("{}/.cache/quickshell", h))
            .unwrap_or_default(),
    );

    let current = fs::read_to_string(TMPFS_STATE)
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "true".to_string());

    let new_state = if current == "true" { "false" } else { "true" };

    let _ = fs::write(persistent_state(), new_state);
    let _ = fs::write(TMPFS_STATE, new_state);

    apply_state(new_state);

    if new_state == "true" {
        let _ = Command::new("waybar").spawn();
    }
}
