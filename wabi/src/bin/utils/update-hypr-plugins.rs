use std::fs;
use std::process::Command;

fn get_cmd_output(cmd: &str, args: &[&str]) -> std::io::Result<String> {
    let output = Command::new(cmd).args(args).output()?;
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!(
        "Checking for Hyprland plugin updates (hyprland-scroll-overview, hyprglass, hypr-dynamic-cursors)..."
    );

    let token = fs::read_to_string("/run/secrets/github-token")
        .ok()
        .map(|s| s.trim().to_string())
        .or_else(|| std::env::var("GITHUB_PERSONAL_ACCESS_TOKEN").ok())
        .or_else(|| std::env::var("GITHUB_TOKEN").ok());

    let mut update_args = vec![
        "flake",
        "update",
        "hyprland-scroll-overview",
        "hyprglass",
        "hypr-dynamic-cursors",
    ];
    let token_arg;
    if let Some(ref t) = token {
        token_arg = format!("github.com={}", t);
        update_args.push("--option");
        update_args.push("access-tokens");
        update_args.push(&token_arg);
    }

    let status = Command::new("nix").args(&update_args).status()?;
    if !status.success() {
        eprintln!("Warning: Failed to run nix flake update for Hyprland plugins.");
        return Ok(());
    }

    match get_cmd_output("git", &["status", "--porcelain", "flake.lock"]) {
        Ok(status_str) if !status_str.trim().is_empty() => {
            println!("Hyprland plugin updates detected! flake.lock was updated.");

            let args: Vec<String> = std::env::args().collect();
            let should_commit = args.contains(&"--commit".to_string());
            if should_commit {
                println!("Staging and committing Hyprland plugin updates...");
                let status = Command::new("git").args(["add", "flake.lock"]).status()?;
                if !status.success() {
                    eprintln!("Failed to git add flake.lock.");
                    std::process::exit(1);
                }

                let commit_msg = "chore: auto-update Hyprland plugins (hyprland-scroll-overview, hyprglass, hypr-dynamic-cursors)";
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
