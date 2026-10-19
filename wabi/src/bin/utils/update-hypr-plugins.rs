use std::fs::{self, OpenOptions};
use std::path::PathBuf;
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

struct FileLock {
    path: PathBuf,
}

impl FileLock {
    fn acquire(name: &str) -> Self {
        let lock_path = std::env::temp_dir().join(format!("doty-{}.lock", name));
        let start = Instant::now();
        loop {
            match OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&lock_path)
            {
                Ok(_) => return FileLock { path: lock_path },
                Err(_) => {
                    if let Ok(meta) = fs::metadata(&lock_path)
                        && let Ok(elapsed) = meta
                            .modified()
                            .and_then(|m| m.elapsed().map_err(std::io::Error::other))
                        && elapsed.as_secs() > 300
                    {
                        let _ = fs::remove_file(&lock_path);
                    }
                    if start.elapsed().as_secs() > 180 {
                        eprintln!(
                            "Warning: Timed out waiting for file lock {:?}, proceeding anyway.",
                            lock_path
                        );
                        return FileLock { path: lock_path };
                    }
                    thread::sleep(Duration::from_millis(100));
                }
            }
        }
    }
}

impl Drop for FileLock {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

fn get_cmd_output(cmd: &str, args: &[&str]) -> std::io::Result<String> {
    let output = Command::new(cmd).args(args).output()?;
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!(
        "Checking for Hyprland plugin updates (hyprland-scroll-overview, hyprglass, hypr-dynamic-cursors, hypr-edgehover, hymission, hyprland-plugins)..."
    );

    let token = fs::read_to_string("/run/secrets/github-token")
        .ok()
        .map(|s| s.trim().to_string())
        .or_else(|| std::env::var("GITHUB_PERSONAL_ACCESS_TOKEN").ok())
        .or_else(|| std::env::var("GITHUB_TOKEN").ok());

    // NOTE: hyprland-plugins is rev-pinned in flake.nix for Hyprland 0.56.2
    // compat, so `nix flake update` leaves it alone until the pin is lifted.
    let mut update_args = vec![
        "flake",
        "update",
        "hyprland-scroll-overview",
        "hyprglass",
        "hypr-dynamic-cursors",
        "hypr-edgehover",
        "hymission",
        "hyprland-plugins",
    ];
    let token_arg;
    if let Some(ref t) = token {
        token_arg = format!("github.com={}", t);
        update_args.push("--option");
        update_args.push("access-tokens");
        update_args.push(&token_arg);
    }

    let mut success = false;
    for attempt in 1..=3 {
        let status = Command::new("nix").args(&update_args).status()?;
        if status.success() {
            success = true;
            break;
        }
        if attempt < 3 {
            thread::sleep(Duration::from_secs(2));
        }
    }

    if !success {
        eprintln!("Warning: Failed to run nix flake update for Hyprland plugins.");
        return Ok(());
    }

    match get_cmd_output("git", &["status", "--porcelain", "flake.lock"]) {
        Ok(status_str) if !status_str.trim().is_empty() => {
            println!("Hyprland plugin updates detected! flake.lock was updated.");

            let args: Vec<String> = std::env::args().collect();
            let should_commit = args.contains(&"--commit".to_string());
            if should_commit {
                let _lock = FileLock::acquire("updater");

                println!("Staging and committing Hyprland plugin updates...");
                let status = Command::new("git").args(["add", "flake.lock"]).status()?;
                if !status.success() {
                    eprintln!("Failed to git add flake.lock.");
                    std::process::exit(1);
                }

                let commit_msg = "chore: auto-update Hyprland plugins (hyprland-scroll-overview, hyprglass, hypr-dynamic-cursors, hypr-edgehover, hymission, hyprland-plugins)";
                let status = Command::new("git")
                    .args(["commit", "--no-gpg-sign", "-m", commit_msg])
                    .status()?;
                if !status.success() {
                    eprintln!("Failed to git commit flake.lock.");
                    std::process::exit(1);
                }
                println!("Committed: {}", commit_msg);
            }
        }
        _ => {
            println!("Hyprland plugins are already up to date!");
        }
    }

    Ok(())
}
