use std::collections::HashSet;
use std::fs::OpenOptions;
use std::io::{IsTerminal, Write};
use std::path::PathBuf;
use std::process::{Command, ExitStatus};
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
                    if let Ok(meta) = std::fs::metadata(&lock_path) {
                        if let Ok(elapsed) = meta
                            .modified()
                            .and_then(|m| m.elapsed().map_err(std::io::Error::other))
                        {
                            if elapsed.as_secs() > 300 {
                                let _ = std::fs::remove_file(&lock_path);
                            }
                        }
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
        let _ = std::fs::remove_file(&self.path);
    }
}

fn print_header(title: &str) {
    println!("\x1b[34m=== {} ===\x1b[0m", title);
}

fn print_step(step: &str) {
    println!("\n\x1b[34m[Step] {}\x1b[0m", step);
}

fn print_success(msg: &str) {
    println!("\x1b[32m{}\x1b[0m", msg);
}

fn print_warning(msg: &str) {
    println!("\x1b[33m{}\x1b[0m", msg);
}

fn print_error(msg: &str) {
    println!("\x1b[31mError: {}\x1b[0m", msg);
}

fn run_cmd_silent(cmd: &str, args: &[&str]) -> bool {
    match Command::new(cmd).args(args).output() {
        Ok(output) if output.status.success() => true,
        Ok(output) => {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let stdout = String::from_utf8_lossy(&output.stdout);
            if !stderr.trim().is_empty() {
                eprintln!("{}", stderr);
            } else if !stdout.trim().is_empty() {
                println!("{}", stdout);
            }
            false
        }
        Err(e) => {
            eprintln!("Failed to execute command '{}': {}", cmd, e);
            false
        }
    }
}

fn run_cmd_silent_in_dir(cmd: &str, args: &[&str], dir: &str) -> bool {
    match Command::new(cmd).args(args).current_dir(dir).output() {
        Ok(output) if output.status.success() => true,
        Ok(output) => {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let stdout = String::from_utf8_lossy(&output.stdout);
            if !stderr.trim().is_empty() {
                eprintln!("{}", stderr);
            } else if !stdout.trim().is_empty() {
                println!("{}", stdout);
            }
            false
        }
        Err(e) => {
            eprintln!("Failed to execute command '{}' in '{}': {}", cmd, dir, e);
            false
        }
    }
}

fn run_cmd(cmd: &str, args: &[&str]) -> std::io::Result<ExitStatus> {
    Command::new(cmd).args(args).status()
}

fn get_cmd_output(cmd: &str, args: &[&str]) -> std::io::Result<String> {
    let output = Command::new(cmd).args(args).output()?;
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

#[derive(Clone, Debug)]
enum AppStatus {
    UpToDate(String),
    Updated(String),
    Warning(String),
    Failed(String),
}

struct AppUpdateResult {
    name: &'static str,
    status: AppStatus,
    duration: Duration,
    retries: usize,
}

fn parse_app_output(stdout: &str) -> AppStatus {
    let mut version = None;
    let mut updated_msg = None;
    let mut is_up_to_date = false;

    for line in stdout.lines() {
        let trim = line.trim();
        if trim.starts_with("Current local ") && trim.contains(" version: ") {
            if let Some(v) = trim.split(": ").nth(1) {
                version = Some(v.trim().to_string());
            }
        }
        if trim.contains("already up to date") || trim.contains("is up to date") {
            is_up_to_date = true;
        }
        if trim.contains("Successfully updated")
            || trim.contains("Committed:")
            || trim.contains("updates detected")
        {
            updated_msg = Some(trim.to_string());
        }
    }

    if let Some(msg) = updated_msg {
        AppStatus::Updated(msg)
    } else if is_up_to_date {
        if let Some(v) = version {
            AppStatus::UpToDate(format!("v{}", v))
        } else {
            AppStatus::UpToDate("up to date".to_string())
        }
    } else {
        AppStatus::UpToDate("up to date".to_string())
    }
}

fn extract_error_msg(stderr: &str, stdout: &str) -> String {
    let raw = if !stderr.trim().is_empty() {
        stderr
    } else if !stdout.trim().is_empty() {
        stdout
    } else {
        "Failed or skipped"
    };

    for line in raw.lines() {
        let t = line.trim();
        if !t.is_empty() && !t.starts_with("Checking for ") {
            return t.to_string();
        }
    }
    "Failed or skipped".to_string()
}

fn run_updater_with_retry(name: &'static str, bin: &'static str, max_retries: usize) -> AppUpdateResult {
    let start = Instant::now();
    let mut attempts = 0;
    loop {
        attempts += 1;
        let output = Command::new(bin).arg("--commit").output();
        match output {
            Ok(out) if out.status.success() => {
                let stdout = String::from_utf8_lossy(&out.stdout);
                let status = parse_app_output(&stdout);
                return AppUpdateResult {
                    name,
                    status,
                    duration: start.elapsed(),
                    retries: attempts - 1,
                };
            }
            Ok(out) => {
                let stderr = String::from_utf8_lossy(&out.stderr);
                let stdout = String::from_utf8_lossy(&out.stdout);
                let err_msg = extract_error_msg(&stderr, &stdout);
                if attempts <= max_retries {
                    thread::sleep(Duration::from_millis(1500 * attempts as u64));
                    continue;
                }
                return AppUpdateResult {
                    name,
                    status: AppStatus::Warning(err_msg),
                    duration: start.elapsed(),
                    retries: attempts - 1,
                };
            }
            Err(e) => {
                if attempts <= max_retries {
                    thread::sleep(Duration::from_millis(1500 * attempts as u64));
                    continue;
                }
                return AppUpdateResult {
                    name,
                    status: AppStatus::Failed(format!("Execution failed: {}", e)),
                    duration: start.elapsed(),
                    retries: attempts - 1,
                };
            }
        }
    }
}

fn update_flake_inputs(token: Option<&str>) -> AppUpdateResult {
    let start = Instant::now();
    let mut update_args = vec![
        "flake",
        "update",
        "hyprland-scroll-overview",
        "hyprglass",
        "hypr-dynamic-cursors",
        "hypr-edgehover",
        "hymission",
        "zen-browser",
        "helium",
        "vscode-insiders",
        "antigravity-nix",
        "codex-desktop-linux",
        "sops-nix",
    ];
    let token_arg;
    if let Some(t) = token {
        token_arg = format!("github.com={}", t);
        update_args.push("--option");
        update_args.push("access-tokens");
        update_args.push(&token_arg);
    }

    let _flake_lock = FileLock::acquire("flake_update");
    let output = Command::new("nix").args(&update_args).output();
    match output {
        Ok(out) if out.status.success() => {
            let status_res = Command::new("git")
                .args(["status", "--porcelain", "flake.lock"])
                .output();
            match status_res {
                Ok(s_out) => {
                    let s_str = String::from_utf8_lossy(&s_out.stdout);
                    if !s_str.trim().is_empty() {
                        let _lock = FileLock::acquire("updater");
                        let add_res = Command::new("git").args(["add", "flake.lock"]).status();
                        let commit_res = Command::new("git")
                            .args(["commit", "--no-gpg-sign", "-m", "chore: update flake.lock"])
                            .status();
                        if add_res.map(|s| s.success()).unwrap_or(false)
                            && commit_res.map(|s| s.success()).unwrap_or(false)
                        {
                            AppUpdateResult {
                                name: "Flake inputs",
                                status: AppStatus::Updated("Committed: chore: update flake.lock".to_string()),
                                duration: start.elapsed(),
                                retries: 0,
                            }
                        } else {
                            AppUpdateResult {
                                name: "Flake inputs",
                                status: AppStatus::Failed("Failed to commit flake.lock changes".to_string()),
                                duration: start.elapsed(),
                                retries: 0,
                            }
                        }
                    } else {
                        AppUpdateResult {
                            name: "Flake inputs",
                            status: AppStatus::UpToDate("up to date".to_string()),
                            duration: start.elapsed(),
                            retries: 0,
                        }
                    }
                }
                Err(e) => AppUpdateResult {
                    name: "Flake inputs",
                    status: AppStatus::Failed(format!("git status failed: {}", e)),
                    duration: start.elapsed(),
                    retries: 0,
                },
            }
        }
        Ok(out) => {
            let stderr = String::from_utf8_lossy(&out.stderr);
            let stdout = String::from_utf8_lossy(&out.stdout);
            let err_msg = extract_error_msg(&stderr, &stdout);
            AppUpdateResult {
                name: "Flake inputs",
                status: AppStatus::Failed(format!("nix flake update failed: {}", err_msg)),
                duration: start.elapsed(),
                retries: 0,
            }
        }
        Err(e) => AppUpdateResult {
            name: "Flake inputs",
            status: AppStatus::Failed(format!("Failed to execute nix flake update: {}", e)),
            duration: start.elapsed(),
            retries: 0,
        },
    }
}

fn update_rea() -> AppUpdateResult {
    let start = Instant::now();
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/parazeeknova".to_string());
    let rea_bin = format!("{}/.npm-global/bin/rea", home);
    let cmd = if std::path::Path::new(&rea_bin).exists() {
        rea_bin
    } else {
        "rea".to_string()
    };

    let output = Command::new(&cmd).arg("update").output();
    match output {
        Ok(out) if out.status.success() => {
            let stdout = String::from_utf8_lossy(&out.stdout);
            let mut status_val = None;
            let mut cur_ver = None;
            let mut latest_ver = None;

            for line in stdout.lines() {
                let trim = line.trim();
                if let Some(rest) = trim.strip_prefix("status:") {
                    status_val = Some(rest.trim().to_string());
                } else if let Some(rest) = trim.strip_prefix("currentVersion:") {
                    cur_ver = Some(rest.trim().to_string());
                } else if let Some(rest) = trim.strip_prefix("latestVersion:") {
                    latest_ver = Some(rest.trim().to_string());
                }
            }

            let app_status = match status_val.as_deref() {
                Some("updated") => {
                    let msg = format!(
                        "Updated to v{}",
                        latest_ver.as_deref().unwrap_or("latest")
                    );
                    AppStatus::Updated(msg)
                }
                _ => {
                    let ver = cur_ver.or(latest_ver).unwrap_or_else(|| "up to date".to_string());
                    if ver.starts_with('v') || ver == "up to date" {
                        AppStatus::UpToDate(ver)
                    } else {
                        AppStatus::UpToDate(format!("v{}", ver))
                    }
                }
            };

            AppUpdateResult {
                name: "REA",
                status: app_status,
                duration: start.elapsed(),
                retries: 0,
            }
        }
        Ok(out) => {
            let stderr = String::from_utf8_lossy(&out.stderr);
            let stdout = String::from_utf8_lossy(&out.stdout);
            let err_msg = extract_error_msg(&stderr, &stdout);
            AppUpdateResult {
                name: "REA",
                status: AppStatus::Warning(format!("rea update: {}", err_msg)),
                duration: start.elapsed(),
                retries: 0,
            }
        }
        Err(e) => AppUpdateResult {
            name: "REA",
            status: AppStatus::Warning(format!("rea not found: {}", e)),
            duration: start.elapsed(),
            retries: 0,
        },
    }
}

fn updaters_need_build() -> bool {
    let update_bins = [
        "update_hypr_plugins",
        "update_portless",
        "update_herdr",
        "update_terminal_browser",
        "update_terminal_code",
        "update_bun",
        "update_supermemory",
        "update_cua",
        "update_t3code",
    ];
    let mut oldest_bin_mtime = None;
    for bin in &update_bins {
        let p = PathBuf::from("wabi/target/release").join(bin);
        match std::fs::metadata(&p) {
            Ok(m) => {
                if let Ok(t) = m.modified() {
                    oldest_bin_mtime =
                        Some(oldest_bin_mtime.map_or(t, |prev: std::time::SystemTime| prev.min(t)));
                } else {
                    return true;
                }
            }
            Err(_) => return true,
        }
    }
    let bin_mtime = match oldest_bin_mtime {
        Some(t) => t,
        None => return true,
    };

    if let Ok(cargo_meta) = std::fs::metadata("wabi/Cargo.toml") {
        if let Ok(m) = cargo_meta.modified() {
            if m > bin_mtime {
                return true;
            }
        }
    }
    if let Ok(entries) = std::fs::read_dir("wabi/src/bin/utils") {
        for entry in entries.flatten() {
            if let Ok(meta) = entry.metadata() {
                if let Ok(m) = meta.modified() {
                    if m > bin_mtime {
                        return true;
                    }
                }
            }
        }
    }
    false
}

fn main() {
    print_header("Starting Rust-powered Rebuild Pipeline");

    let args: Vec<String> = std::env::args().collect();
    let force_update = args
        .iter()
        .any(|a| a == "--update" || a == "-u" || a == "--check" || a == "-c");

    // Read GitHub token if available to prevent API rate limiting on nix commands
    let token = std::fs::read_to_string("/run/secrets/github-token")
        .ok()
        .map(|s| s.trim().to_string())
        .or_else(|| std::env::var("GITHUB_PERSONAL_ACCESS_TOKEN").ok())
        .or_else(|| std::env::var("GITHUB_TOKEN").ok());

    // Step 0: Check Git Working Directory status
    print_step("Checking Git working tree status...");
    match get_cmd_output("git", &["status", "--porcelain"]) {
        Ok(status) => {
            // Filter out untracked rebuild binary, rebuild.rs, and gitignores to keep things clean.
            let lines: Vec<&str> = status
                .lines()
                .filter(|line| {
                    let trim_line = line.trim();
                    !trim_line.is_empty()
                        && !trim_line.ends_with("rebuild")
                        && !trim_line.ends_with("rebuild.rs")
                        && !trim_line.ends_with(".gitignore")
                })
                .collect();

            if !lines.is_empty() {
                print_error("Git working directory is dirty. Please clean the branch or commit your manual changes before running the rebuild pipeline.");
                let _ = run_cmd("git", &["status", "-s"]);
                std::process::exit(1);
            }
            print_success("Git working tree is clean.");
        }
        Err(e) => {
            print_error(&format!("Failed to run git status: {}", e));
            std::process::exit(1);
        }
    }

    // Step 1: Check and update standalone applications & Nix flake inputs in parallel
    print_step("Checking and updating applications, REA, and Nix flake inputs in parallel...");

    let cache_path = std::env::temp_dir().join("doty-step1-cache.txt");
    let mut used_cache = false;

    if !force_update && cache_path.exists() {
        if let Ok(meta) = std::fs::metadata(&cache_path) {
            if let Ok(elapsed) = meta
                .modified()
                .and_then(|m| m.elapsed().map_err(std::io::Error::other))
            {
                if elapsed.as_secs() < 3600 {
                    if let Ok(content) = std::fs::read_to_string(&cache_path) {
                        let lines: Vec<&str> = content.lines().filter(|l| !l.is_empty()).collect();
                        if !lines.is_empty() {
                            for line in &lines {
                                println!("{}", line);
                            }
                            let mins = elapsed.as_secs() / 60;
                            print_success(&format!(
                                "Package and flake inputs check completed in 0.0s (all up to date, checked {}m ago; pass -u to refresh).",
                                mins
                            ));
                            used_cache = true;
                        }
                    }
                }
            }
        }
    }

    if !used_cache {
        let (tx, rx) = std::sync::mpsc::channel();
        let mut in_flight: HashSet<&'static str> = HashSet::new();
        let mut cached_lines: Vec<String> = Vec::new();

        // Spawn flake update thread immediately so it runs concurrently with building & running updaters
        let token_clone = token.clone();
        let flake_tx = tx.clone();
        in_flight.insert("Flake inputs");
        thread::spawn(move || {
            let res = update_flake_inputs(token_clone.as_deref());
            let _ = flake_tx.send(res);
        });

        // Spawn REA update thread in parallel
        let rea_tx = tx.clone();
        in_flight.insert("REA");
        thread::spawn(move || {
            let res = update_rea();
            let _ = rea_tx.send(res);
        });

        println!("-> Compiling application updater tools...");
        if !updaters_need_build() {
            print_success("Updater tools ready (up to date).");
        } else {
            let update_bins = [
                "update_hypr_plugins",
                "update_portless",
                "update_herdr",
                "update_terminal_browser",
                "update_terminal_code",
                "update_bun",
                "update_supermemory",
                "update_cua",
                "update_t3code",
            ];
            let mut cargo_args = vec!["build", "--manifest-path", "wabi/Cargo.toml", "--release"];
            for bin in &update_bins {
                cargo_args.push("--bin");
                cargo_args.push(bin);
            }
            if run_cmd_silent("cargo", &cargo_args) {
                print_success("Updater tools ready.");
            } else if run_cmd_silent(
                "nix-shell",
                &[
                    "-p",
                    "pkg-config",
                    "openssl",
                    "--run",
                    &format!("cargo {}", cargo_args.join(" ")),
                ],
            ) {
                print_success("Updater tools ready.");
            } else {
                print_warning(
                    "Failed to build updater tools; attempting to proceed with existing binaries.",
                );
            }
        }

        let app_updates = [
            ("Hyprland plugins", "./wabi/target/release/update_hypr_plugins"),
            ("Portless", "./wabi/target/release/update_portless"),
            ("Herdr", "./wabi/target/release/update_herdr"),
            ("Terminal Browser", "./wabi/target/release/update_terminal_browser"),
            ("Terminal Code", "./wabi/target/release/update_terminal_code"),
            ("Bun", "./wabi/target/release/update_bun"),
            ("Supermemory", "./wabi/target/release/update_supermemory"),
            ("Cua", "./wabi/target/release/update_cua"),
            ("T3 Code", "./wabi/target/release/update_t3code"),
        ];

        println!("-> Checking 9 applications in parallel...");

        for (name, bin) in app_updates {
            in_flight.insert(name);
            let thread_tx = tx.clone();
            thread::spawn(move || {
                let res = run_updater_with_retry(name, bin, 2);
                let _ = thread_tx.send(res);
            });
        }
        drop(tx);

        let total = in_flight.len();
        let start_all = Instant::now();
        let mut completed = 0;
        let mut updated_count = 0;
        let mut up_to_date_count = 0;
        let mut warn_count = 0;
        let mut flake_failed_msg = None;

        let is_tty = std::io::stdout().is_terminal();

        while completed < total {
            match rx.recv_timeout(Duration::from_millis(250)) {
                Ok(res) => {
                    completed += 1;
                    in_flight.remove(res.name);

                    if is_tty {
                        print!("\r\x1b[K");
                    }

                    let retry_str = if res.retries > 0 {
                        format!(" \x1b[90m({} retries)\x1b[0m", res.retries)
                    } else {
                        String::new()
                    };

                    let dur_str = format!("{:.1}s", res.duration.as_secs_f64());

                    if res.name == "Flake inputs" {
                        if let AppStatus::Failed(ref msg) = res.status {
                            flake_failed_msg = Some(msg.clone());
                        }
                    }

                    match &res.status {
                        AppStatus::UpToDate(ver) => {
                            up_to_date_count += 1;
                            println!(
                                "  \x1b[32m✓\x1b[0m {:<18} \x1b[90m{:<12} ({})\x1b[0m{}",
                                res.name, ver, dur_str, retry_str
                            );
                            cached_lines.push(format!(
                                "  \x1b[32m✓\x1b[0m {:<18} \x1b[90m{:<12} (cached)\x1b[0m",
                                res.name, ver
                            ));
                        }
                        AppStatus::Updated(msg) => {
                            updated_count += 1;
                            println!(
                                "  \x1b[36m↑\x1b[0m {:<18} \x1b[32m{}\x1b[0m \x1b[90m({})\x1b[0m{}",
                                res.name, msg, dur_str, retry_str
                            );
                        }
                        AppStatus::Warning(msg) => {
                            warn_count += 1;
                            println!(
                                "  \x1b[33m⚠\x1b[0m {:<18} \x1b[33m{}\x1b[0m \x1b[90m({})\x1b[0m{}",
                                res.name, msg, dur_str, retry_str
                            );
                        }
                        AppStatus::Failed(msg) => {
                            warn_count += 1;
                            println!(
                                "  \x1b[31m✗\x1b[0m {:<18} \x1b[31m{}\x1b[0m \x1b[90m({})\x1b[0m{}",
                                res.name, msg, dur_str, retry_str
                            );
                        }
                    }
                }
                Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
                    if is_tty && completed < total {
                        let running: Vec<&str> = in_flight.iter().copied().collect();
                        print!(
                            "\r\x1b[K  \x1b[34m⠋\x1b[0m [{}/{}] Checking: {}...",
                            completed,
                            total,
                            running.join(", ")
                        );
                        let _ = std::io::stdout().flush();
                    }
                }
                Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
            }
        }

        if is_tty {
            print!("\r\x1b[K");
            let _ = std::io::stdout().flush();
        }

        let elapsed = start_all.elapsed();
        let time_str = format!("{:.1}s", elapsed.as_secs_f64());
        if warn_count == 0 {
            print_success(&format!(
                "Package and flake inputs check completed in {} ({} up to date, {} updated).",
                time_str, up_to_date_count, updated_count
            ));
            if flake_failed_msg.is_none() && updated_count == 0 {
                let _ = std::fs::write(&cache_path, cached_lines.join("\n"));
            }
        } else {
            print_warning(&format!(
                "Package and flake inputs check completed in {} ({} up to date, {} updated, {} warnings/skips).",
                time_str, up_to_date_count, updated_count, warn_count
            ));
            let _ = std::fs::remove_file(&cache_path);
        }

        if let Some(err) = flake_failed_msg {
            print_error(&format!("Nix flake update failed: {}", err));
            std::process::exit(1);
        }
    }

    // Step 2: Lint, format, and build wabi
    print_step("Linting, formatting, and building wabi...");

    println!("-> wabi: cargo clippy --all-targets -- -D warnings");
    if run_cmd_silent_in_dir("cargo", &["clippy", "--all-targets", "--", "-D", "warnings"], "wabi") {
        print_success("wabi clippy passed.");
    } else {
        print_error("wabi clippy failed.");
        std::process::exit(1);
    }

    println!("-> wabi: cargo fmt --all");
    if run_cmd_silent_in_dir("cargo", &["fmt", "--all", "--", "--check"], "wabi") {
        print_success("wabi formatting is correct.");
    } else {
        print_error("wabi formatting check failed. Run 'cargo fmt --all' in wabi directory.");
        std::process::exit(1);
    }

    println!("-> wabi: cargo build --release + make install");
    if !run_cmd_silent_in_dir("cargo", &["build", "--release"], "wabi") {
        print_error("wabi build failed.");
        std::process::exit(1);
    }
    if run_cmd_silent_in_dir("make", &["install"], "wabi") {
        print_success("wabi built and installed successfully.");
    } else {
        print_error("wabi install failed.");
        std::process::exit(1);
    }

    // Step 3: Format and lint QML, Nix, and Lua files in parallel
    print_step("Formatting and linting QML / Nix / Lua files in parallel...");

    let (fmt_tx, fmt_rx) = std::sync::mpsc::channel();

    // Thread 1: QML format & lint
    let tx_qml = fmt_tx.clone();
    thread::spawn(move || {
        let ok_fmt = run_cmd_silent(
            "nix-shell",
            &[
                "-p",
                "qt6.qtdeclarative",
                "--run",
                "find modules/features/wm/quickshell -type f -name '*.qml' -exec qmlformat -i {} +",
            ],
        );
        if !ok_fmt {
            let _ = tx_qml.send((false, "QML formatting failed."));
            return;
        }
        let qml_lint = Command::new("nix-shell")
            .args(&[
                "-p",
                "qt6.qtdeclarative",
                "--run",
                "find modules/features/wm/quickshell -type f -name '*.qml' -exec qmllint {} +",
            ])
            .output();
        match qml_lint {
            Ok(output) if output.status.success() => {
                let _ = tx_qml.send((true, "QML format & lint passed."));
            }
            Ok(output) => {
                eprintln!("{}", String::from_utf8_lossy(&output.stderr));
                let _ = tx_qml.send((false, "QML lint found syntax errors."));
            }
            Err(e) => {
                eprintln!("Failed to run qmllint: {}", e);
                let _ = tx_qml.send((false, "Failed to run qmllint."));
            }
        }
    });

    // Thread 2: Nix format & check
    let tx_nix = fmt_tx.clone();
    thread::spawn(move || {
        let nix_files_output = get_cmd_output(
            "find",
            &[
                ".", "-name", "*.nix", "-not", "-path", "./.git/*", "-not", "-path", "./wabi/*",
            ],
        );
        if let Ok(files) = nix_files_output {
            let file_list: Vec<&str> = files.lines().filter(|s| !s.is_empty()).collect();
            if !file_list.is_empty() {
                if !run_cmd_silent("nixfmt", &file_list) {
                    let _ = tx_nix.send((false, "nixfmt formatting failed."));
                    return;
                }
                let mut check_args = vec!["-c"];
                check_args.extend(file_list);
                if !run_cmd_silent("nixfmt", &check_args) {
                    let _ = tx_nix.send((false, "nixfmt formatting check failed."));
                    return;
                }
            }
        }
        let _ = tx_nix.send((true, "Nix format check passed."));
    });

    // Thread 3: Lua format & check
    let tx_lua = fmt_tx.clone();
    thread::spawn(move || {
        let ok_fmt = run_cmd_silent(
            "nix-shell",
            &[
                "-p",
                "stylua",
                "--run",
                "find modules/features/wm/hyprland/hypr -type f -name '*.lua' -exec stylua {} +",
            ],
        );
        if !ok_fmt {
            let _ = tx_lua.send((false, "Lua formatting failed."));
            return;
        }
        let ok_check = run_cmd_silent(
            "nix-shell",
            &[
                "-p",
                "stylua",
                "--run",
                "find modules/features/wm/hyprland/hypr -type f -name '*.lua' -exec stylua --check {} +",
            ],
        );
        if !ok_check {
            let _ = tx_lua.send((false, "Lua formatting check failed."));
            return;
        }
        let _ = tx_lua.send((true, "Lua format check passed."));
    });
    drop(fmt_tx);

    let mut any_fmt_failed = false;
    for (success, msg) in fmt_rx {
        if success {
            print_success(&format!("✓ {}", msg));
        } else {
            print_error(msg);
            any_fmt_failed = true;
        }
    }
    if any_fmt_failed {
        std::process::exit(1);
    }

    // Step 4: Nix flake check
    print_step("Running nix flake check...");
    let mut check_args = vec!["flake", "check"];
    check_args.push("--impure");
    let check_token_arg;
    if let Some(ref t) = token {
        check_token_arg = format!("github.com={}", t);
        check_args.push("--option");
        check_args.push("access-tokens");
        check_args.push(&check_token_arg);
    }
    if run_cmd_silent("nix", &check_args) {
        print_success("nix flake check passed.");
    } else {
        print_error("nix flake check failed.");
        std::process::exit(1);
    }

    // Step 5: Git clean check & commit formatting changes if any
    print_step("Checking for auto-formatting changes...");
    match get_cmd_output("git", &["status", "--porcelain"]) {
        Ok(status) => {
            let lines: Vec<&str> = status
                .lines()
                .filter(|line| {
                    let trim_line = line.trim();
                    !trim_line.is_empty()
                        && !trim_line.ends_with("rebuild")
                        && !trim_line.ends_with("rebuild.rs")
                        && !trim_line.ends_with(".gitignore")
                })
                .collect();

            if !lines.is_empty() {
                print_warning("Formatting changed some files. Committing formatting updates...");
                if run_cmd_silent("git", &["add", "-A"])
                    && run_cmd_silent(
                        "git",
                        &[
                            "commit",
                            "--no-gpg-sign",
                            "-m",
                            "style: auto-format Nix, QML, and Lua files",
                        ],
                    )
                {
                    print_success("Formatting changes committed successfully.");
                } else {
                    print_error("Failed to commit formatting changes.");
                    std::process::exit(1);
                }
            } else {
                print_success("No formatting changes detected. Working tree remains clean.");
            }
        }
        Err(e) => {
            print_error(&format!("Failed to run git status: {}", e));
            std::process::exit(1);
        }
    }

    // Step 6: Nix Garbage Collection & Generation Cleanup
    print_step("Deleting old system generations (keeping last 12)...");
    match run_cmd(
        "sudo",
        &[
            "nix-env",
            "-p",
            "/nix/var/nix/profiles/system",
            "--delete-generations",
            "+12",
        ],
    ) {
        Ok(status) if status.success() => print_success("Old system generations deleted."),
        _ => print_warning("Failed to delete old system generations."),
    }

    print_step("Collecting Nix garbage...");
    match run_cmd("sudo", &["nix-collect-garbage"]) {
        Ok(status) if status.success() => {
            print_success("Garbage collection completed successfully.")
        }
        _ => print_warning("Garbage collection failed or skipped."),
    }

    // Step 7: System Rebuild
    print_step("Rebuilding NixOS configuration...");
    match run_cmd("sudo", &["nixos-rebuild", "switch", "--flake", ".#apostrophe"]) {
        Ok(status) if status.success() => {
            print_success("\n=== Rebuild Pipeline Completed Successfully ===")
        }
        _ => {
            print_error("NixOS rebuild switch failed.");
            std::process::exit(1);
        }
    }
}
