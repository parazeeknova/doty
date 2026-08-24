use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn get_latest_bun_version() -> Option<String> {
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

    args.push("https://api.github.com/repos/oven-sh/bun/releases/latest");

    let output = Command::new("curl").args(args).output().ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch bun release info from GitHub API.");
        return None;
    }

    let json = String::from_utf8_lossy(&output.stdout);
    let tag = extract_field(&json, "\"tag_name\":\"", "\"")?;

    let version = tag
        .strip_prefix("bun-v")
        .or_else(|| tag.strip_prefix('v'))
        .unwrap_or(&tag);

    Some(version.to_string())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for Bun updates...");

    let dev_nix_path = Path::new("modules/hosts/apostrophe/packages/dev.nix");
    if !dev_nix_path.exists() {
        eprintln!("Error: {:?} not found.", dev_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(dev_nix_path)?;

    // Locate bun block
    let start_idx = content
        .find("pname = \"bun\";")
        .ok_or("Cannot find bun definition in dev.nix")?;
    let bun_block = &content[start_idx..];

    let current_version =
        extract_field(bun_block, "version = \"", "\";").ok_or("Cannot find current bun version")?;
    let current_hash =
        extract_field(bun_block, "sha256 = \"", "\";").ok_or("Cannot find current bun hash")?;

    println!("Current local bun version: {}", current_version);

    let latest_version = match get_latest_bun_version() {
        Some(v) => v,
        None => {
            eprintln!("Warning: Could not check for bun updates. Skipping update check.");
            return Ok(());
        }
    };

    println!("Latest online bun version: {}", latest_version);

    if latest_version == current_version {
        println!("Bun is already up to date!");
        return Ok(());
    }

    println!(
        "New version {} available! Fetching new hash...",
        latest_version
    );
    let new_url = format!(
        "https://github.com/oven-sh/bun/releases/download/bun-v{}/bun-linux-x64.zip",
        latest_version
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

    let content = fs::read_to_string(dev_nix_path)?;
    let start_idx = content
        .find("pname = \"bun\";")
        .ok_or("Cannot find bun definition in dev.nix")?;
    let end_idx = content[start_idx..]
        .find("};")
        .ok_or("Cannot find end of bun block")?
        + start_idx
        + 2;
    let old_block = &content[start_idx..end_idx];

    let mut new_block = old_block.to_string();
    new_block = new_block.replace(
        &format!("version = \"{}\";", current_version),
        &format!("version = \"{}\";", latest_version),
    );
    new_block = new_block.replace(
        &format!("sha256 = \"{}\";", current_hash),
        &format!("sha256 = \"{}\";", new_hash),
    );

    let mut new_content = content.clone();
    new_content.replace_range(start_idx..end_idx, &new_block);
    fs::write(dev_nix_path, new_content)?;

    println!(
        "Successfully updated dev.nix to bun version {} with hash {}",
        latest_version, new_hash
    );

    let args: Vec<String> = std::env::args().collect();
    let should_commit = args.contains(&"--commit".to_string());
    if should_commit {
        println!("Staging and committing changes to Git...");
        let status = Command::new("git")
            .args(["add", "modules/hosts/apostrophe/packages/dev.nix"])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git add.");
            std::process::exit(1);
        }

        let commit_msg = format!("chore: auto-update bun to version {}", latest_version);
        let status = Command::new("git")
            .args(["commit", "-m", &commit_msg])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git commit.");
            std::process::exit(1);
        }
        println!("Committed: {}", commit_msg);
    }

    println!("Bun update complete!");

    Ok(())
}
