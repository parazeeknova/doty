use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn get_latest_cline_version() -> Option<String> {
    let args = [
        "-s",
        "-H",
        "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
        "https://registry.npmjs.org/@cline/cli-linux-x64/latest",
    ];

    let output = Command::new("curl").args(args).output().ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch cline info from npm registry.");
        return None;
    }

    let json = String::from_utf8_lossy(&output.stdout);
    extract_field(&json, "\"version\":\"", "\"")
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for Cline updates...");

    let cline_nix_path = Path::new("modules/features/applications/cline/default.nix");
    if !cline_nix_path.exists() {
        eprintln!("Error: {:?} not found.", cline_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(cline_nix_path)?;

    let start_idx = content
        .find("pname = \"cline\";")
        .ok_or("Cannot find cline definition in cline/default.nix")?;
    let cline_block = &content[start_idx..];

    let current_version = extract_field(cline_block, "version = \"", "\";")
        .ok_or("Cannot find current cline version")?;
    let current_hash =
        extract_field(cline_block, "sha256 = \"", "\";").ok_or("Cannot find current cline hash")?;

    println!("Current local cline version: {}", current_version);

    let latest_version = match get_latest_cline_version() {
        Some(v) => v,
        None => {
            eprintln!("Warning: Could not check for Cline updates. Skipping update check.");
            return Ok(());
        }
    };

    println!("Latest online cline version: {}", latest_version);

    if latest_version == current_version {
        println!("Cline is already up to date!");
        return Ok(());
    }

    println!(
        "New version {} available! Fetching new hash...",
        latest_version
    );
    let new_url = format!(
        "https://registry.npmjs.org/@cline/cli-linux-x64/-/cli-linux-x64-{}.tgz",
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

    let content = fs::read_to_string(cline_nix_path)?;
    let start_idx = content
        .find("pname = \"cline\";")
        .ok_or("Cannot find cline definition in cline/default.nix")?;
    let end_idx = content[start_idx..]
        .find("};")
        .ok_or("Cannot find end of cline block")?
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
    fs::write(cline_nix_path, new_content)?;

    println!(
        "Successfully updated cline/default.nix to cline version {} with hash {}",
        latest_version, new_hash
    );

    let args: Vec<String> = std::env::args().collect();
    let should_commit = args.contains(&"--commit".to_string());
    if should_commit {
        println!("Staging and committing changes to Git...");
        let status = Command::new("git")
            .args(["add", "modules/features/applications/cline/default.nix"])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git add.");
            std::process::exit(1);
        }

        let commit_msg = format!("chore: auto-update cline to version {}", latest_version);
        let status = Command::new("git")
            .args(["commit", "-m", &commit_msg])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git commit.");
            std::process::exit(1);
        }
        println!("Committed: {}", commit_msg);
    }

    println!("Cline update complete!");

    Ok(())
}
