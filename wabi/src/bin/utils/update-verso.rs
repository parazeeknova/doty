use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}


fn get_latest_verso_version() -> Option<String> {
    let output = Command::new("curl")
        .args([
            "-s",
            "-H",
            "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
            "https://api.github.com/repos/parazeeknova/verso/releases/latest",
        ])
        .output()
        .ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch Verso release info from GitHub API.");
        return None;
    }

    let json = String::from_utf8_lossy(&output.stdout);
    let tag = extract_field(&json, "\"tag_name\":\"", "\"")?;
    
    // Strip leading 'v' if present
    if let Some(stripped) = tag.strip_prefix('v') {
        Some(stripped.to_string())
    } else {
        Some(tag)
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for Verso updates...");

    let desktop_nix_path = Path::new("modules/hosts/apostrophe/packages/desktop.nix");
    if !desktop_nix_path.exists() {
        eprintln!("Error: {:?} not found.", desktop_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(desktop_nix_path)?;

    // Locate Verso block
    let start_idx = content
        .find("# -- Verso --")
        .ok_or("Cannot find Verso header")?;
    let verso_block = &content[start_idx..];

    let current_version =
        extract_field(verso_block, "version = \"", "\";").ok_or("Cannot find current version")?;
    let current_hash =
        extract_field(verso_block, "sha256 = \"", "\";").ok_or("Cannot find current hash")?;

    println!("Current local version: {}", current_version);

    let latest_version = match get_latest_verso_version() {
        Some(v) => v,
        None => {
            eprintln!("Warning: Could not check for Verso updates. Skipping update check.");
            return Ok(());
        }
    };

    println!("Latest online version: {}", latest_version);

    if latest_version == current_version {
        println!("Verso is already up to date!");
        return Ok(());
    }

    println!(
        "New version {} available! Fetching new hash...",
        latest_version
    );
    let new_url = format!(
        "https://github.com/parazeeknova/verso/releases/download/v{}/Verso-{}-x86_64.AppImage",
        latest_version, latest_version
    );

    let output = Command::new("nix-prefetch-url").arg(&new_url).output()?;

    if !output.status.success() {
        eprintln!("Failed to get hash from nix-prefetch-url.");
        std::process::exit(1);
    }

    let new_hash = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if new_hash.is_empty() {
        eprintln!("nix-prefetch-url returned an empty hash.");
        std::process::exit(1);
    }
    println!("Fetched hash: {}", new_hash);

    // Re-read file to avoid race conditions and replace the block
    let content = fs::read_to_string(desktop_nix_path)?;
    let start_idx = content
        .find("# -- Verso --")
        .ok_or("Cannot find Verso header")?;
    let end_idx = content[start_idx..]
        .find("})")
        .ok_or("Cannot find end of Verso block")?
        + start_idx
        + 2;
    let old_block = &content[start_idx..end_idx];

    let mut new_block = old_block.to_string();
    new_block = new_block.replace(
        &format!("version = \"{}\";", current_version),
        &format!("version = \"{}\";", latest_version),
    );
    new_block = new_block.replace(
        &format!("download/v{}/", current_version),
        &format!("download/v{}/", latest_version),
    );
    new_block = new_block.replace(
        &format!("Verso-{}-x86_64", current_version),
        &format!("Verso-{}-x86_64", latest_version),
    );
    new_block = new_block.replace(
        &format!("sha256 = \"{}\";", current_hash),
        &format!("sha256 = \"{}\";", new_hash),
    );

    let mut new_content = content.clone();
    new_content.replace_range(start_idx..end_idx, &new_block);
    fs::write(desktop_nix_path, new_content)?;

    println!(
        "Successfully updated desktop.nix to version {} with hash {}",
        latest_version, new_hash
    );

    let args: Vec<String> = std::env::args().collect();
    let should_commit = args.contains(&"--commit".to_string());
    if should_commit {
        println!("Staging and committing changes to Git...");
        let status = Command::new("git")
            .args(["add", "modules/hosts/apostrophe/packages/desktop.nix"])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git add.");
            std::process::exit(1);
        }

        let commit_msg = format!("chore: auto-update Verso to version {}", latest_version);
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
