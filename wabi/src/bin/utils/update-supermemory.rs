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

fn get_latest_supermemory_version() -> Option<String> {
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

    args.push("https://api.github.com/repos/supermemoryai/supermemory/releases");

    let stdout = curl_with_retry(&args)?;
    let releases: serde_json::Value = serde_json::from_str(&stdout).ok()?;
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
    println!("Checking for supermemory updates...");

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

    let new_hash = nix_prefetch_url_with_retry(&new_url, 3)?;
    println!("Fetched hash: {}", new_hash);

    let _lock = FileLock::acquire("updater");

    let fresh_content = fs::read_to_string(supermemory_nix_path)?;
    let start_idx = fresh_content
        .find("pname = \"supermemory-server\";")
        .ok_or("Cannot find supermemory-server definition in supermemory.nix")?;
    let end_idx = fresh_content[start_idx..]
        .find("};")
        .ok_or("Cannot find end of supermemory-server block")?
        + start_idx
        + 2;
    let old_block = &fresh_content[start_idx..end_idx];

    let mut new_block = old_block.to_string();
    new_block = new_block.replace(
        &format!("version = \"{}\";", current_version),
        &format!("version = \"{}\";", latest_version),
    );
    new_block = new_block.replace(
        &format!("sha256 = \"{}\";", current_hash),
        &format!("sha256 = \"{}\";", new_hash),
    );

    let mut new_content = fresh_content.clone();
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
            .args(["commit", "--no-gpg-sign", "-m", &commit_msg])
            .status()?;
        if !status.success() {
            eprintln!("Failed to run git commit.");
            std::process::exit(1);
        }
        println!("Committed: {}", commit_msg);
    }

    println!("Supermemory server update complete!");

    Ok(())
}
