use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn get_latest_supermemory_version() -> Option<String> {
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

    args.push("https://api.github.com/repos/supermemoryai/supermemory/releases");

    let output = Command::new("curl").args(args).output().ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch supermemory release info from GitHub API.");
        return None;
    }

    let json_str = String::from_utf8_lossy(&output.stdout);
    let releases: serde_json::Value = serde_json::from_str(&json_str).ok()?;
    let releases_arr = releases.as_array()?;

    for rel in releases_arr {
        if let Some(tag) = rel.get("tag_name").and_then(|t| t.as_str())
            && let Some(ver) = tag.strip_prefix("server-v")
            && !ver.contains("-rc")
        {
            return Some(ver.to_string());
        }
    }

    None
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for Supermemory server updates...");

    let supermemory_nix_path = Path::new("modules/features/llms/supermemory.nix");
    if !supermemory_nix_path.exists() {
        eprintln!("Error: {:?} not found.", supermemory_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(supermemory_nix_path)?;

    // Locate supermemory-server block
    let start_idx = content
        .find("pname = \"supermemory-server\";")
        .ok_or("Cannot find supermemory-server definition in supermemory.nix")?;
    let block = &content[start_idx..];

    let current_version = extract_field(block, "version = \"", "\";")
        .ok_or("Cannot find current supermemory-server version")?;
    let current_hash = extract_field(block, "sha256 = \"", "\";")
        .ok_or("Cannot find current supermemory-server hash")?;

    println!(
        "Current local supermemory-server version: {}",
        current_version
    );

    let latest_version = match get_latest_supermemory_version() {
        Some(v) => v,
        None => {
            eprintln!("Warning: Could not check for supermemory updates. Skipping update check.");
            return Ok(());
        }
    };

    println!(
        "Latest online supermemory-server version: {}",
        latest_version
    );

    if latest_version == current_version {
        println!("Supermemory server is already up to date!");
        return Ok(());
    }

    println!(
        "New version {} available! Fetching new hash...",
        latest_version
    );
    let new_url = format!(
        "https://github.com/supermemoryai/supermemory/releases/download/server-v{}/supermemory-server-linux-x64",
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

    let end_idx = content[start_idx..]
        .find("};")
        .ok_or("Cannot find end of supermemory-server block")?
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
    fs::write(supermemory_nix_path, new_content)?;

    println!(
        "Successfully updated supermemory.nix to supermemory-server version {} with hash {}",
        latest_version, new_hash
    );

    let args: Vec<String> = std::env::args().collect();
    let should_commit = args.contains(&"--commit".to_string());
    if should_commit {
        println!("Staging and committing changes to Git...");
        let status = Command::new("git")
            .args(["add", "modules/features/llms/supermemory.nix"])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git add.");
            std::process::exit(1);
        }

        let commit_msg = format!(
            "chore: auto-update supermemory-server to version {}",
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

    println!("Supermemory update complete!");

    Ok(())
}
