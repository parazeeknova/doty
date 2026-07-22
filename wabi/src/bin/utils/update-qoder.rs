use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for Qoder updates...");

    let desktop_nix_path = Path::new("modules/hosts/apostrophe/packages/desktop.nix");
    if !desktop_nix_path.exists() {
        eprintln!("Error: {:?} not found.", desktop_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(desktop_nix_path)?;

    // Locate Qoder block
    let start_idx = content
        .find("# -- Qoder --")
        .ok_or("Cannot find Qoder header")?;
    let qoder_block = &content[start_idx..];

    let current_hash =
        extract_field(qoder_block, "sha256 = \"", "\";").ok_or("Cannot find current hash")?;

    let download_url = "https://download.qoder.com/release/latest/qoder_amd64.deb";

    let output = Command::new("nix-prefetch-url")
        .arg(download_url)
        .output()?;

    if !output.status.success() {
        eprintln!("Failed to get hash from nix-prefetch-url.");
        std::process::exit(1);
    }

    let new_hash = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if new_hash.is_empty() {
        eprintln!("nix-prefetch-url returned an empty hash.");
        std::process::exit(1);
    }

    if new_hash == current_hash {
        println!("Qoder is already up to date!");
        return Ok(());
    }

    println!(
        "New Qoder update available! Updating hash to {}...",
        new_hash
    );

    // Re-read file to avoid race conditions and replace the block
    let content = fs::read_to_string(desktop_nix_path)?;
    let start_idx = content
        .find("# -- Qoder --")
        .ok_or("Cannot find Qoder header")?;
    let end_idx = content[start_idx..]
        .find("})")
        .ok_or("Cannot find end of Qoder block")?
        + start_idx
        + 2;
    let old_block = &content[start_idx..end_idx];

    let new_block = old_block.replace(
        &format!("sha256 = \"{}\";", current_hash),
        &format!("sha256 = \"{}\";", new_hash),
    );

    let mut new_content = content.clone();
    new_content.replace_range(start_idx..end_idx, &new_block);
    fs::write(desktop_nix_path, new_content)?;

    println!(
        "Successfully updated desktop.nix Qoder hash to {}",
        new_hash
    );

    let args: Vec<String> = std::env::args().collect();
    let should_commit = args.contains(&"--commit".to_string());
    if should_commit {
        println!("Staging and committing changes to Git... ");
        let status = Command::new("git")
            .args(["add", "modules/hosts/apostrophe/packages/desktop.nix"])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git add.");
            std::process::exit(1);
        }

        let commit_msg = "chore: auto-update Qoder package hash".to_string();
        let status = Command::new("git")
            .args(["commit", "-m", &commit_msg])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git commit.");
            std::process::exit(1);
        }
        println!("Committed: {}", commit_msg);
    }

    println!("Update complete!");

    Ok(())
}
