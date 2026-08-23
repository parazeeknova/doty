use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn get_latest_suwayomi_version() -> Option<String> {
    let mut args = vec![
        "-s",
        "-H",
        "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
    ];

    let mut token = fs::read_to_string("/run/secrets/github-token")
        .ok()
        .map(|s| s.trim().to_string());

    if token.is_none() {
        token = std::env::var("GITHUB_PERSONAL_ACCESS_TOKEN")
            .ok()
            .or_else(|| std::env::var("GITHUB_TOKEN").ok());
    }

    let auth_header;
    if let Some(t) = token {
        auth_header = format!("Authorization: Bearer {}", t);
        args.push("-H");
        args.push(&auth_header);
    }

    args.push("https://api.github.com/repos/Suwayomi/Suwayomi-Server/releases/latest");

    let output = Command::new("curl").args(args).output().ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch Suwayomi-Server release info from GitHub API.");
        return None;
    }

    let json = String::from_utf8_lossy(&output.stdout);
    let tag = extract_field(&json, "\"tag_name\":\"", "\"")?;

    if let Some(stripped) = tag.strip_prefix('v') {
        Some(stripped.to_string())
    } else {
        Some(tag)
    }
}

fn convert_to_sri(base32_hash: &str) -> Result<String, Box<dyn std::error::Error>> {
    let output = Command::new("nix")
        .args(["hash", "to-sri", "--type", "sha256", base32_hash])
        .output()?;
    if !output.status.success() {
        return Err("Failed to convert hash to SRI format".into());
    }
    let sri = String::from_utf8_lossy(&output.stdout).trim().to_string();
    Ok(sri)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for Suwayomi-Server updates...");

    let suwayomi_nix_path = Path::new("modules/features/applications/suwayomi/default.nix");
    if !suwayomi_nix_path.exists() {
        eprintln!("Error: {:?} not found.", suwayomi_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(suwayomi_nix_path)?;

    // Locate suwayomi block
    let current_version = extract_field(&content, "version = \"", "\";")
        .ok_or("Cannot find current suwayomi version")?;
    let current_hash =
        extract_field(&content, "hash = \"", "\";").ok_or("Cannot find current suwayomi hash")?;

    println!("Current local Suwayomi-Server version: {}", current_version);

    let latest_version = match get_latest_suwayomi_version() {
        Some(v) => v,
        None => {
            eprintln!(
                "Warning: Could not check for Suwayomi-Server updates. Skipping update check."
            );
            return Ok(());
        }
    };

    println!("Latest online Suwayomi-Server version: {}", latest_version);

    if latest_version == current_version {
        println!("Suwayomi-Server is already up to date!");
        return Ok(());
    }

    println!(
        "New version {} available! Fetching new hash...",
        latest_version
    );
    let new_url = format!(
        "https://github.com/Suwayomi/Suwayomi-Server/releases/download/v{}/Suwayomi-Server-v{}.jar",
        latest_version, latest_version
    );

    let output = Command::new("nix-prefetch-url").arg(&new_url).output()?;

    if !output.status.success() {
        eprintln!("Failed to get hash from nix-prefetch-url.");
        std::process::exit(1);
    }

    let raw_hash = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if raw_hash.is_empty() {
        eprintln!("nix-prefetch-url returned an empty hash.");
        std::process::exit(1);
    }

    let new_sri = convert_to_sri(&raw_hash)?;
    println!("Fetched hash: {}", new_sri);

    let mut new_content = content.clone();
    new_content = new_content.replace(
        &format!("version = \"{}\";", current_version),
        &format!("version = \"{}\";", latest_version),
    );
    new_content = new_content.replace(
        &format!("hash = \"{}\";", current_hash),
        &format!("hash = \"{}\";", new_sri),
    );

    fs::write(suwayomi_nix_path, new_content)?;

    println!(
        "Successfully updated suwayomi/default.nix to Suwayomi-Server version {} with hash {}",
        latest_version, new_sri
    );

    let args: Vec<String> = std::env::args().collect();
    let should_commit = args.contains(&"--commit".to_string());
    if should_commit {
        println!("Staging and committing changes to Git...");
        let status = Command::new("git")
            .args(["add", "modules/features/applications/suwayomi/default.nix"])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git add.");
            std::process::exit(1);
        }

        let commit_msg = format!(
            "chore: auto-update suwayomi-server to version {}",
            latest_version
        );
        let status = Command::new("git")
            .args(["commit", "-m", &commit_msg])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git commit.");
            std::process::exit(1);
        }
        println!("Committed: {}", commit_msg);
    }

    println!("Suwayomi-Server update complete!");

    Ok(())
}
