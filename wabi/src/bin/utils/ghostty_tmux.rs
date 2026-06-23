use std::process::Command;

fn main() {
    let session_name = "ghostty";

    // Check if the session already exists
    let has_session = Command::new("tmux")
        .args(["has-session", "-t", session_name])
        .status()
        .map(|status| status.success())
        .unwrap_or(false);

    if has_session {
        // Reattach to session
        let _ = Command::new("tmux")
            .args(["attach-session", "-t", session_name])
            .status();
    } else {
        // Create session in background and attach
        let _ = Command::new("tmux")
            .args(["new-session", "-s", session_name, "-d"])
            .status();
        let _ = Command::new("tmux")
            .args(["attach-session", "-t", session_name])
            .status();
    }
}
