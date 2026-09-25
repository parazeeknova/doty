use std::fs;
use std::path::Path;
use std::process::Command;

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].trim().to_string())
}

fn get_latest_comfy_info() -> Option<(String, String, String)> {
    let args = [
        "-s",
        "-H",
        "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
        "https://download.todesktop.com/241130tqe9q3y/latest-linux.yml",
    ];

    let output = Command::new("curl").args(args).output().ok()?;

    if !output.status.success() {
        eprintln!("Failed to fetch ComfyUI Desktop info from ToDesktop.");
        return None;
    }

    let yml = String::from_utf8_lossy(&output.stdout);
    let version = extract_field(&yml, "version: ", "\n")?;
    let path = extract_field(&yml, "path: ", "\n")?;
    let build_id = extract_field(&path, "-build-", "-x86_64.AppImage").unwrap_or_default();

    Some((version, build_id, path))
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for ComfyUI Desktop updates...");

    let comfy_nix_path = Path::new("modules/features/applications/comfy-desktop/default.nix");
    if !comfy_nix_path.exists() {
        eprintln!("Error: {:?} not found.", comfy_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(comfy_nix_path)?;

    let start_idx = content
        .find("pname = \"comfy-desktop\";")
        .ok_or("Cannot find comfy-desktop definition in comfy-desktop/default.nix")?;
    let comfy_block = &content[start_idx..];

    let current_version = extract_field(comfy_block, "version = \"", "\";")
        .ok_or("Cannot find current comfy-desktop version")?;
    let current_build_id = extract_field(comfy_block, "buildId = \"", "\";").unwrap_or_default();
    let current_hash = extract_field(comfy_block, "sha256 = \"", "\";")
        .ok_or("Cannot find current comfy-desktop hash")?;

    println!(
        "Current local ComfyUI Desktop version: {} (build {})",
        current_version, current_build_id
    );

    let (latest_version, latest_build_id, latest_path) = match get_latest_comfy_info() {
        Some(info) => info,
        None => {
            eprintln!(
                "Warning: Could not check for ComfyUI Desktop updates. Skipping update check."
            );
            return Ok(());
        }
    };

    println!(
        "Latest online ComfyUI Desktop version: {} (build {})",
        latest_version, latest_build_id
    );

    if latest_version == current_version && latest_build_id == current_build_id {
        println!("ComfyUI Desktop is already up to date!");
        return Ok(());
    }

    println!(
        "New version {} (build {}) available! Fetching new hash...",
        latest_version, latest_build_id
    );
    let new_url = format!(
        "https://download.todesktop.com/241130tqe9q3y/{}",
        latest_path
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

    let content = fs::read_to_string(comfy_nix_path)?;
    let start_idx = content
        .find("pname = \"comfy-desktop\";")
        .ok_or("Cannot find comfy-desktop definition in comfy-desktop/default.nix")?;
    let end_idx = content[start_idx..]
        .find("};")
        .ok_or("Cannot find end of comfy-desktop block")?
        + start_idx
        + 2;
    let old_block = &content[start_idx..end_idx];

    let mut new_block = old_block.to_string();
    new_block = new_block.replace(
        &format!("version = \"{}\";", current_version),
        &format!("version = \"{}\";", latest_version),
    );
    new_block = new_block.replace(
        &format!("buildId = \"{}\";", current_build_id),
        &format!("buildId = \"{}\";", latest_build_id),
    );
    new_block = new_block.replace(
        &format!("sha256 = \"{}\";", current_hash),
        &format!("sha256 = \"{}\";", new_hash),
    );

    let mut new_content = content.clone();
    new_content.replace_range(start_idx..end_idx, &new_block);
    fs::write(comfy_nix_path, new_content)?;

    println!(
        "Successfully updated comfy-desktop/default.nix to version {} (build {}) with hash {}",
        latest_version, latest_build_id, new_hash
    );

    let args: Vec<String> = std::env::args().collect();
    let should_commit = args.contains(&"--commit".to_string());
    if should_commit {
        println!("Staging and committing changes to Git...");
        let status = Command::new("git")
            .args([
                "add",
                "modules/features/applications/comfy-desktop/default.nix",
            ])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git add.");
            std::process::exit(1);
        }

        let commit_msg = format!(
            "chore: auto-update ComfyUI Desktop to version {}",
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

    println!("ComfyUI Desktop update complete!");

    Ok(())
}
