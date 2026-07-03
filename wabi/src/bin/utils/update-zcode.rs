use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn parse_version(v: &str) -> Vec<u32> {
    v.split('.').filter_map(|s| s.parse::<u32>().ok()).collect()
}

fn get_latest_zcode_version() -> Option<String> {
    let output = Command::new("curl")
        .args([
            "-s",
            "-H",
            "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
            "https://zcode.z.ai/en",
        ])
        .output()
        .ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch ZCode website using curl.");
        return None;
    }

    let html = String::from_utf8_lossy(&output.stdout);
    let pattern = "https://cdn-zcode.z.ai/zcode/electron/releases/";
    let mut versions = Vec::new();
    let mut search_str = &*html;

    while let Some(idx) = search_str.find(pattern) {
        let start = idx + pattern.len();
        let remaining = &search_str[start..];
        if let Some(slash_idx) = remaining.find('/') {
            let version = &remaining[..slash_idx];
            if version.chars().all(|c| c.is_ascii_digit() || c == '.') && !version.is_empty() {
                versions.push(version.to_string());
            }
        }
        search_str = remaining;
    }

    if versions.is_empty() {
        eprintln!("Could not find any ZCode release versions on page.");
        return None;
    }

    // Sort versions semantically and return the highest
    versions.sort_by_key(|v| parse_version(v));
    versions.last().cloned()
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for ZCode updates...");

    let desktop_nix_path = Path::new("modules/hosts/apostrophe/packages/desktop.nix");
    if !desktop_nix_path.exists() {
        eprintln!("Error: {:?} not found.", desktop_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(desktop_nix_path)?;

    // Locate ZCode block
    let start_idx = content
        .find("# -- ZCode --")
        .ok_or("Cannot find ZCode header")?;
    let zcode_block = &content[start_idx..];

    let current_version =
        extract_field(zcode_block, "version = \"", "\";").ok_or("Cannot find current version")?;
    let current_hash =
        extract_field(zcode_block, "sha256 = \"", "\";").ok_or("Cannot find current hash")?;

    println!("Current local version: {}", current_version);

    let latest_version = match get_latest_zcode_version() {
        Some(v) => v,
        None => std::process::exit(1),
    };

    println!("Latest online version: {}", latest_version);

    if latest_version == current_version {
        println!("ZCode is already up to date!");
        return Ok(());
    }

    println!(
        "New version {} available! Fetching new hash...",
        latest_version
    );
    let new_url = format!(
        "https://cdn-zcode.z.ai/zcode/electron/releases/{}/ZCode-{}-linux-x64.AppImage",
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
        .find("# -- ZCode --")
        .ok_or("Cannot find ZCode header")?;
    let end_idx = content[start_idx..]
        .find("})")
        .ok_or("Cannot find end of ZCode block")?
        + start_idx
        + 2;
    let old_block = &content[start_idx..end_idx];

    let mut new_block = old_block.to_string();
    new_block = new_block.replace(
        &format!("version = \"{}\";", current_version),
        &format!("version = \"{}\";", latest_version),
    );
    new_block = new_block.replace(
        &format!("releases/{}/", current_version),
        &format!("releases/{}/", latest_version),
    );
    new_block = new_block.replace(
        &format!("ZCode-{}-linux", current_version),
        &format!("ZCode-{}-linux", latest_version),
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
    println!("Update complete!");

    Ok(())
}
