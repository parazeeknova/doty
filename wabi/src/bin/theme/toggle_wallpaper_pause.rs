use std::fs;
use std::io::Write;
use std::os::unix::net::UnixStream;
use std::process::Command;
use wabi::cache_dir;

fn main() {
    let home = std::env::var("HOME").unwrap_or_default();
    let paused_flag = cache_dir().join("live_wallpaper_paused");
    let osdctl = format!("{}/.config/quickshell/osd/bin/osdctl", home);
    let socket_path = "/tmp/mpvpaper-ipc";

    // Attempt to connect to the mpvpaper IPC socket
    let mut stream = match UnixStream::connect(socket_path) {
        Ok(s) => s,
        Err(_) => {
            // mpvpaper is not running/responsive
            let _ = Command::new(&osdctl)
                .args(["show", "no live wallpaper", "info", "1200"])
                .status();
            return;
        }
    };

    // Ensure parent directory exists
    if let Some(parent) = paused_flag.parent() {
        let _ = fs::create_dir_all(parent);
    }

    // Check current state
    let is_paused = fs::read_to_string(&paused_flag)
        .map(|s| s.trim() == "true")
        .unwrap_or(false);

    if is_paused {
        // Currently paused -> Resume
        let _ = fs::write(&paused_flag, "false");

        // Send resume command over IPC socket
        let _ = writeln!(stream, r#"{{"command": ["set_property", "pause", false]}}"#);

        let _ = Command::new(&osdctl)
            .args(["show", "live wallpaper resumed", "good", "1200"])
            .status();
    } else {
        // Currently running -> Pause
        let _ = fs::write(&paused_flag, "true");

        // Send pause command over IPC socket
        let _ = writeln!(stream, r#"{{"command": ["set_property", "pause", true]}}"#);

        let _ = Command::new(&osdctl)
            .args(["show", "live wallpaper paused", "warn", "1200"])
            .status();
    }
}
