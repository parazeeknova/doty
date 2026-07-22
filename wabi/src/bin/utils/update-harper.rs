use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn get_latest_harper_version() -> Option<String> {
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

    args.push("https://api.github.com/repos/Automattic/harper/releases/latest");

    let output = Command::new("curl").args(&args).output().ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch Harper release info from GitHub API.");
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
    println!("Checking for Harper updates...");

    let desktop_nix_path = Path::new("modules/hosts/apostrophe/packages/desktop.nix");
    if !desktop_nix_path.exists() {
        eprintln!("Error: {:?} not found.", desktop_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(desktop_nix_path)?;

    // Locate Harper block
    let start_idx = content
        .find("# -- Harper --")
        .ok_or("Cannot find Harper header")?;
    let harper_block = &content[start_idx..];

    let current_version =
        extract_field(harper_block, "version = \"", "\";").ok_or("Cannot find current version")?;

    println!("Current local version: {}", current_version);

    let latest_version = match get_latest_harper_version() {
        Some(v) => v,
        None => {
            eprintln!("Warning: Could not check for Harper updates. Skipping update check.");
            return Ok(());
        }
    };

    println!("Latest online version: {}", latest_version);

    if latest_version == current_version {
        println!("Harper is already up to date!");
        return Ok(());
    }

    println!(
        "New version {} available! Fetching new hashes...",
        latest_version
    );
    let cli_url = format!(
        "https://github.com/Automattic/harper/releases/download/v{}/harper-cli-x86_64-unknown-linux-gnu.tar.gz",
        latest_version
    );
    let ls_url = format!(
        "https://github.com/Automattic/harper/releases/download/v{}/harper-ls-x86_64-unknown-linux-gnu.tar.gz",
        latest_version
    );

    let output_cli = Command::new("nix-prefetch-url").arg(&cli_url).output()?;
    let output_ls = Command::new("nix-prefetch-url").arg(&ls_url).output()?;

    if !output_cli.status.success() || !output_ls.status.success() {
        eprintln!("Failed to get hashes from nix-prefetch-url.");
        std::process::exit(1);
    }

    let new_cli_hash = String::from_utf8_lossy(&output_cli.stdout).trim().to_string();
    let new_ls_hash = String::from_utf8_lossy(&output_ls.stdout).trim().to_string();

    if new_cli_hash.is_empty() || new_ls_hash.is_empty() {
        eprintln!("nix-prefetch-url returned an empty hash.");
        std::process::exit(1);
    }

    // Re-read file to avoid race conditions and replace the block
    let content = fs::read_to_string(desktop_nix_path)?;
    let start_idx = content
        .find("# -- Harper --")
        .ok_or("Cannot find Harper header")?;
    let end_idx = content[start_idx..]
        .find("})")
        .ok_or("Cannot find end of Harper block")?
        + start_idx
        + 2;
    let old_block = &content[start_idx..end_idx];

    let current_cli_hash =
        extract_field(old_block, "sha256 = \"", "\";").ok_or("Cannot find current cli hash")?;
    let remaining = &old_block[old_block.find("ls_src").unwrap_or(0)..];
    let current_ls_hash =
        extract_field(remaining, "sha256 = \"", "\";").ok_or("Cannot find current ls hash")?;

    let mut new_block = old_block.to_string();
    new_block = new_block.replace(
        &format!("version = \"{}\";", current_version),
        &format!("version = \"{}\";", latest_version),
    );
    new_block = new_block.replace(
        &format!("sha256 = \"{}\";", current_cli_hash),
        &format!("sha256 = \"{}\";", new_cli_hash),
    );
    new_block = new_block.replace(
        &format!("sha256 = \"{}\";", current_ls_hash),
        &format!("sha256 = \"{}\";", new_ls_hash),
    );

    let mut new_content = content.clone();
    new_content.replace_range(start_idx..end_idx, &new_block);
    fs::write(desktop_nix_path, new_content)?;

    println!(
        "Successfully updated desktop.nix Harper to version {}",
        latest_version
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

        let commit_msg = format!("chore: auto-update Harper to version {}", latest_version);
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
