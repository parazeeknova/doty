use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn get_latest_versions() -> Option<(String, String)> {
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

    args.push("https://api.github.com/repos/trycua/cua/releases");

    let output = Command::new("curl").args(args).output().ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch cua releases info from GitHub API.");
        return None;
    }

    let json_str = String::from_utf8_lossy(&output.stdout);
    let releases: serde_json::Value = serde_json::from_str(&json_str).ok()?;
    let releases_arr = releases.as_array()?;

    let mut latest_cli: Option<String> = None;
    let mut latest_driver: Option<String> = None;

    for rel in releases_arr {
        if let Some(tag) = rel.get("tag_name").and_then(|t| t.as_str()) {
            if latest_cli.is_none()
                && let Some(ver) = tag.strip_prefix("cua-sdk-v")
                && !ver.contains("-rc")
            {
                latest_cli = Some(ver.to_string());
            }
            if latest_driver.is_none()
                && let Some(ver) = tag.strip_prefix("cua-driver-rs-v")
                && !ver.contains("-rc")
            {
                latest_driver = Some(ver.to_string());
            }
            if latest_cli.is_some() && latest_driver.is_some() {
                break;
            }
        }
    }

    match (latest_cli, latest_driver) {
        (Some(cli), Some(driver)) => Some((cli, driver)),
        _ => None,
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for Cua updates...");

    let cua_nix_path = Path::new("modules/features/llms/cua.nix");
    if !cua_nix_path.exists() {
        eprintln!("Error: {:?} not found.", cua_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(cua_nix_path)?;

    // Locate cua block
    let cua_start = content
        .find("pname = \"cua\";")
        .ok_or("Cannot find cua definition in cua.nix")?;
    let cua_block = &content[cua_start..];
    let current_cua_version =
        extract_field(cua_block, "version = \"", "\";").ok_or("Cannot find current cua version")?;
    let current_cua_hash =
        extract_field(cua_block, "sha256 = \"", "\";").ok_or("Cannot find current cua hash")?;

    // Locate cua-driver block
    let driver_start = content
        .find("pname = \"cua-driver\";")
        .ok_or("Cannot find cua-driver definition in cua.nix")?;
    let driver_block = &content[driver_start..];
    let current_driver_version = extract_field(driver_block, "version = \"", "\";")
        .ok_or("Cannot find current cua-driver version")?;
    let current_driver_hash = extract_field(driver_block, "sha256 = \"", "\";")
        .ok_or("Cannot find current cua-driver hash")?;

    println!(
        "Current local cua CLI: v{}, cua-driver: v{}",
        current_cua_version, current_driver_version
    );

    let (latest_cli, latest_driver) = match get_latest_versions() {
        Some(versions) => versions,
        None => {
            eprintln!("Warning: Could not check for cua updates. Skipping update check.");
            return Ok(());
        }
    };

    println!(
        "Latest online cua CLI: v{}, cua-driver: v{}",
        latest_cli, latest_driver
    );

    let cli_needs_update = latest_cli != current_cua_version;
    let driver_needs_update = latest_driver != current_driver_version;

    if !cli_needs_update && !driver_needs_update {
        println!("Cua is already up to date!");
        return Ok(());
    }

    let mut new_content = content;

    if cli_needs_update {
        println!("New cua CLI v{} available! Fetching hash...", latest_cli);
        let url = format!(
            "https://github.com/trycua/cua/releases/download/cua-sdk-v{}/cua-cli-{}-linux-x64.tar.gz",
            latest_cli, latest_cli
        );
        let out = Command::new("nix-prefetch-url").arg(&url).output()?;
        if !out.status.success() {
            eprintln!("Failed to fetch hash for cua CLI.");
            std::process::exit(1);
        }
        let new_hash = String::from_utf8_lossy(&out.stdout).trim().to_string();

        let cua_start = new_content.find("pname = \"cua\";").unwrap();
        let cua_end = new_content[cua_start..].find("};").unwrap() + cua_start + 2;
        let old_block = &new_content[cua_start..cua_end];

        let mut updated_block = old_block.to_string();
        updated_block = updated_block.replace(
            &format!("version = \"{}\";", current_cua_version),
            &format!("version = \"{}\";", latest_cli),
        );
        updated_block = updated_block.replace(
            &format!("sha256 = \"{}\";", current_cua_hash),
            &format!("sha256 = \"{}\";", new_hash),
        );

        new_content.replace_range(cua_start..cua_end, &updated_block);
        println!("Updated cua CLI to v{}", latest_cli);
    }

    if driver_needs_update {
        println!(
            "New cua-driver v{} available! Fetching hash...",
            latest_driver
        );
        let url = format!(
            "https://github.com/trycua/cua/releases/download/cua-driver-rs-v{}/cua-driver-rs-{}-linux-x86_64-binary.tar.gz",
            latest_driver, latest_driver
        );
        let out = Command::new("nix-prefetch-url").arg(&url).output()?;
        if !out.status.success() {
            eprintln!("Failed to fetch hash for cua-driver.");
            std::process::exit(1);
        }
        let new_hash = String::from_utf8_lossy(&out.stdout).trim().to_string();

        let driver_start = new_content.find("pname = \"cua-driver\";").unwrap();
        let driver_end = new_content[driver_start..].find("};").unwrap() + driver_start + 2;
        let old_block = &new_content[driver_start..driver_end];

        let mut updated_block = old_block.to_string();
        updated_block = updated_block.replace(
            &format!("version = \"{}\";", current_driver_version),
            &format!("version = \"{}\";", latest_driver),
        );
        updated_block = updated_block.replace(
            &format!("sha256 = \"{}\";", current_driver_hash),
            &format!("sha256 = \"{}\";", new_hash),
        );

        new_content.replace_range(driver_start..driver_end, &updated_block);
        println!("Updated cua-driver to v{}", latest_driver);
    }

    fs::write(cua_nix_path, new_content)?;

    let args: Vec<String> = std::env::args().collect();
    let should_commit = args.contains(&"--commit".to_string());
    if should_commit {
        println!("Staging and committing changes to Git...");
        let status = Command::new("git")
            .args(["add", "modules/features/llms/cua.nix"])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git add.");
            std::process::exit(1);
        }

        let commit_msg = format!(
            "chore: auto-update cua (cli: v{}, driver: v{})",
            latest_cli, latest_driver
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

    println!("Cua update complete!");

    Ok(())
}
