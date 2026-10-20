use std::fs::{self, OpenOptions};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

struct FileLock {
    path: PathBuf,
}

impl FileLock {
    fn acquire(name: &str) -> Self {
        let lock_path = std::env::temp_dir().join(format!("doty-{}.lock", name));
        let start = Instant::now();
        loop {
            match OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&lock_path)
            {
                Ok(_) => return FileLock { path: lock_path },
                Err(_) => {
                    if let Ok(meta) = fs::metadata(&lock_path)
                        && let Ok(elapsed) = meta
                            .modified()
                            .and_then(|m| m.elapsed().map_err(std::io::Error::other))
                        && elapsed.as_secs() > 300
                    {
                        let _ = fs::remove_file(&lock_path);
                    }
                    if start.elapsed().as_secs() > 180 {
                        eprintln!(
                            "Warning: Timed out waiting for file lock {:?}, proceeding anyway.",
                            lock_path
                        );
                        return FileLock { path: lock_path };
                    }
                    thread::sleep(Duration::from_millis(100));
                }
            }
        }
    }
}

impl Drop for FileLock {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

fn extract_field(content: &str, start_pattern: &str, end_pattern: &str) -> Option<String> {
    let start_idx = content.find(start_pattern)?;
    let val_start = start_idx + start_pattern.len();
    let end_idx = content[val_start..].find(end_pattern)?;
    Some(content[val_start..val_start + end_idx].to_string())
}

fn curl_with_retry(args: &[&str]) -> Option<String> {
    let mut full_args = vec![
        "-s",
        "--retry",
        "3",
        "--retry-delay",
        "1",
        "--retry-connrefused",
        "--connect-timeout",
        "10",
        "--max-time",
        "30",
        "-H",
        "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
    ];
    full_args.extend_from_slice(args);
    let output = Command::new("curl").args(&full_args).output().ok()?;
    if output.status.success() {
        Some(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        None
    }
}

fn nix_prefetch_url_with_retry(url: &str, retries: u32) -> Result<String, String> {
    let mut last_err = String::new();
    for attempt in 1..=retries {
        let output = Command::new("nix-prefetch-url")
            .arg(url)
            .output()
            .map_err(|e| format!("Failed to execute nix-prefetch-url: {}", e))?;

        if output.status.success() {
            let hash = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !hash.is_empty() {
                return Ok(hash);
            }
        }
        let stderr = String::from_utf8_lossy(&output.stderr);
        last_err = if !stderr.trim().is_empty() {
            stderr.trim().to_string()
        } else {
            "Empty hash returned".to_string()
        };
        if attempt < retries {
            thread::sleep(Duration::from_secs(2));
        }
    }
    Err(format!(
        "nix-prefetch-url failed after {} attempts: {}",
        retries, last_err
    ))
}

fn get_latest_cua_versions() -> (Option<String>, Option<String>) {
    let mut args = Vec::new();

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

    let stdout = match curl_with_retry(&args) {
        Some(s) => s,
        None => {
            eprintln!("Failed to fetch cua releases info from GitHub API.");
            return (None, None);
        }
    };

    let releases: serde_json::Value = match serde_json::from_str(&stdout) {
        Ok(v) => v,
        Err(_) => return (None, None),
    };
    let releases_arr = match releases.as_array() {
        Some(arr) => arr,
        None => return (None, None),
    };

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

    (latest_cli, latest_driver)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Checking for Cua updates...");

    let cua_nix_path = Path::new("modules/features/llms/cua.nix");
    if !cua_nix_path.exists() {
        eprintln!("Error: {:?} not found.", cua_nix_path);
        std::process::exit(1);
    }

    let content = fs::read_to_string(cua_nix_path)?;

    // Locate cua CLI block
    let cua_idx = content
        .find("pname = \"cua\";")
        .ok_or("Cannot find cua definition in cua.nix")?;
    let cua_block = &content[cua_idx..];
    let current_cua_version =
        extract_field(cua_block, "version = \"", "\";").ok_or("Cannot find current cua version")?;
    let current_cua_hash =
        extract_field(cua_block, "sha256 = \"", "\";").ok_or("Cannot find current cua hash")?;

    // Locate cua-driver block
    let driver_idx = content
        .find("pname = \"cua-driver\";")
        .ok_or("Cannot find cua-driver definition in cua.nix")?;
    let driver_block = &content[driver_idx..];
    let current_driver_version = extract_field(driver_block, "version = \"", "\";")
        .ok_or("Cannot find current cua-driver version")?;
    let current_driver_hash = extract_field(driver_block, "sha256 = \"", "\";")
        .ok_or("Cannot find current cua-driver hash")?;

    println!(
        "Current local Cua CLI version: {}, driver version: {}",
        current_cua_version, current_driver_version
    );

    let (latest_cli_opt, latest_driver_opt) = get_latest_cua_versions();
    let latest_cli = match latest_cli_opt {
        Some(v) => v,
        None => {
            eprintln!("Warning: Could not check for Cua CLI updates. Skipping update check.");
            return Ok(());
        }
    };
    let latest_driver = match latest_driver_opt {
        Some(v) => v,
        None => {
            eprintln!("Warning: Could not check for Cua driver updates. Skipping update check.");
            return Ok(());
        }
    };

    println!(
        "Latest online Cua CLI version: {}, driver version: {}",
        latest_cli, latest_driver
    );

    let cli_needs_update = latest_cli != current_cua_version;
    let driver_needs_update = latest_driver != current_driver_version;

    if !cli_needs_update && !driver_needs_update {
        println!("Cua CLI and driver are already up to date!");
        return Ok(());
    }

    let mut new_cli_hash = None;
    if cli_needs_update {
        println!("New cua CLI v{} available! Fetching hash...", latest_cli);
        let url = format!(
            "https://github.com/trycua/cua/releases/download/cua-sdk-v{}/cua-cli-{}-linux-x64.tar.gz",
            latest_cli, latest_cli
        );
        let hash = nix_prefetch_url_with_retry(&url, 3)?;
        println!("Fetched cua CLI hash: {}", hash);
        new_cli_hash = Some(hash);
    }

    let mut new_driver_hash = None;
    if driver_needs_update {
        println!(
            "New cua-driver v{} available! Fetching hash...",
            latest_driver
        );
        let url = format!(
            "https://github.com/trycua/cua/releases/download/cua-driver-rs-v{}/cua-driver-rs-{}-linux-x86_64-binary.tar.gz",
            latest_driver, latest_driver
        );
        let hash = nix_prefetch_url_with_retry(&url, 3)?;
        println!("Fetched cua-driver hash: {}", hash);
        new_driver_hash = Some(hash);
    }

    let _lock = FileLock::acquire("updater");

    let fresh_content = fs::read_to_string(cua_nix_path)?;
    let mut new_content = fresh_content;

    if let Some(hash) = new_cli_hash {
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
            &format!("sha256 = \"{}\";", hash),
        );

        new_content.replace_range(cua_start..cua_end, &updated_block);
        println!("Updated cua CLI to v{}", latest_cli);
    }

    if let Some(hash) = new_driver_hash {
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
            &format!("sha256 = \"{}\";", hash),
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
            .args(["commit", "--no-gpg-sign", "-m", &commit_msg])
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
