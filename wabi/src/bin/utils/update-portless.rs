use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn get_latest_portless_version() -> Option<String> {
    let args = [
        "-s",
        "-H",
        "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
        "https://registry.npmjs.org/portless/latest",
    ];

    let output = Command::new("curl").args(args).output().ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch portless info from npm registry.");
        return None;
    }

    let json = String::from_utf8_lossy(&output.stdout);
    extract_field(&json, "\"version\":\"", "\"")
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for Portless updates...");

    let portless_nix_path = Path::new("modules/features/applications/portless/default.nix");
    if !portless_nix_path.exists() {
        eprintln!("Error: {:?} not found.", portless_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(portless_nix_path)?;

    // Locate Portless block
    let start_idx = content
        .find("pname = \"portless\";")
        .ok_or("Cannot find portless definition in portless/default.nix")?;
    let portless_block = &content[start_idx..];

    let current_version = extract_field(portless_block, "version = \"", "\";")
        .ok_or("Cannot find current portless version")?;
    let current_hash = extract_field(portless_block, "sha256 = \"", "\";")
        .ok_or("Cannot find current portless hash")?;

    println!("Current local portless version: {}", current_version);

    let latest_version = match get_latest_portless_version() {
        Some(v) => v,
        None => {
            eprintln!("Warning: Could not check for Portless updates. Skipping update check.");
            return Ok(());
        }
    };

    println!("Latest online portless version: {}", latest_version);

    if latest_version == current_version {
        println!("Portless is already up to date!");
        return Ok(());
    }

    println!(
        "New version {} available! Fetching new hash...",
        latest_version
    );
    let new_url = format!(
        "https://registry.npmjs.org/portless/-/portless-{}.tgz",
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

    let content = fs::read_to_string(portless_nix_path)?;
    let start_idx = content
        .find("pname = \"portless\";")
        .ok_or("Cannot find portless definition in portless/default.nix")?;
    let end_idx = content[start_idx..]
        .find("};")
        .ok_or("Cannot find end of portless block")?
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
    fs::write(portless_nix_path, new_content)?;

    println!(
        "Successfully updated portless/default.nix to portless version {} with hash {}",
        latest_version, new_hash
    );

    let args: Vec<String> = std::env::args().collect();
    let should_commit = args.contains(&"--commit".to_string());
    if should_commit {
        println!("Staging and committing changes to Git...");
        let status = Command::new("git")
            .args(["add", "modules/features/applications/portless/default.nix"])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git add.");
            std::process::exit(1);
        }

        let commit_msg = format!("chore: auto-update portless to version {}", latest_version);
        let status = Command::new("git")
            .args(["commit", "-m", &commit_msg])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git commit.");
            std::process::exit(1);
        }
        println!("Committed: {}", commit_msg);
    }

    println!("Portless update complete!");

    Ok(())
}
