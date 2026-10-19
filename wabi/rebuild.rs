use std::collections::HashSet;
use std::io::{IsTerminal, Write};
use std::process::{Command, ExitStatus};
use std::thread;
use std::time::{Duration, Instant};

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

fn main() {
    print_header("Starting Rust-powered Rebuild Pipeline");

    // Read GitHub token if available to prevent API rate limiting on nix commands
    let token = std::fs::read_to_string("/run/secrets/github-token")
        .ok()
        .map(|s| s.trim().to_string());

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

    // Step 1: Check and update standalone applications
    print_step("Checking and updating standalone applications...");

    println!("-> Compiling application updater tools...");
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
        print_warning("Failed to build updater tools; attempting to proceed with existing binaries.");
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

    let (tx, rx) = std::sync::mpsc::channel();
    let total = app_updates.len();
    let mut in_flight: HashSet<&'static str> = app_updates.iter().map(|(n, _)| *n).collect();

    for (name, bin) in app_updates {
        let thread_tx = tx.clone();
        thread::spawn(move || {
            let res = run_updater_with_retry(name, bin, 2);
            let _ = thread_tx.send(res);
        });
    }
    drop(tx);

    let start_all = Instant::now();
    let mut completed = 0;
    let mut updated_count = 0;
    let mut up_to_date_count = 0;
    let mut warn_count = 0;

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

                match &res.status {
                    AppStatus::UpToDate(ver) => {
                        up_to_date_count += 1;
                        println!(
                            "  \x1b[32m✓\x1b[0m {:<18} \x1b[90m{:<12} ({})\x1b[0m{}",
                            res.name, ver, dur_str, retry_str
                        );
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
            "Standalone applications check completed in {} ({} up to date, {} updated).",
            time_str, up_to_date_count, updated_count
        ));
    } else {
        print_warning(&format!(
            "Standalone applications check completed in {} ({} up to date, {} updated, {} warnings/skips).",
            time_str, up_to_date_count, updated_count, warn_count
        ));
    }

    // Step 2: Update Nix Flake inputs
    print_step("Updating Nix flake inputs...");
    let mut update_args = vec!["flake", "update"];
    let token_arg;
    if let Some(ref t) = token {
        token_arg = format!("github.com={}", t);
        update_args.push("--option");
        update_args.push("access-tokens");
        update_args.push(&token_arg);
    }
    if run_cmd("nix", &update_args).map(|s| s.success()).unwrap_or(false) {
        print_success("Flake inputs updated successfully.");
        match get_cmd_output("git", &["status", "--porcelain", "flake.lock"]) {
            Ok(status) if !status.trim().is_empty() => {
                print_warning("flake.lock has changed. Committing...");
                if run_cmd_silent("git", &["add", "flake.lock"])
                    && run_cmd_silent("git", &["commit", "--no-gpg-sign", "-m", "chore: update flake.lock"])
                {
                    print_success("flake.lock committed successfully.");
                } else {
                    print_error("Failed to commit flake.lock changes.");
                    std::process::exit(1);
                }
            }
            _ => {
                print_success("flake.lock is already up to date.");
            }
        }
    } else {
        print_error("nix flake update failed.");
        std::process::exit(1);
    }

    // Step 3: Lint, format, and build wabi
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

    // Step 4: Format QML, Nix, and Lua files
    print_step("Formatting and linting QML / Nix / Lua files...");

    println!("-> Formatting QML files...");
    if run_cmd_silent(
        "nix-shell",
        &[
            "-p",
            "qt6.qtdeclarative",
            "--run",
            "find modules/features/wm/quickshell -type f -name '*.qml' -exec qmlformat -i {} +",
        ],
    ) {
        print_success("QML files formatted.");
    } else {
        print_error("QML formatting failed.");
        std::process::exit(1);
    }

    println!("-> Linting QML files...");
    // We capture qmllint output and only treat non-zero exits as structural errors
    let qml_lint_output = Command::new("nix-shell")
        .args(&[
            "-p",
            "qt6.qtdeclarative",
            "--run",
            "find modules/features/wm/quickshell -type f -name '*.qml' -exec qmllint {} +",
        ])
        .output();
    match qml_lint_output {
        Ok(output) if output.status.success() => {
            print_success("QML lint passed.");
        }
        Ok(output) => {
            print_error("QML lint found syntax errors:");
            eprintln!("{}", String::from_utf8_lossy(&output.stderr));
            std::process::exit(1);
        }
        Err(e) => {
            print_error(&format!("Failed to run qmllint: {}", e));
            std::process::exit(1);
        }
    }

    println!("-> Formatting Nix files...");
    let nix_files_output = get_cmd_output(
        "find",
        &[
            ".", "-name", "*.nix", "-not", "-path", "./.git/*", "-not", "-path", "./wabi/*",
        ],
    );
    if let Ok(files) = nix_files_output {
        let file_list: Vec<&str> = files.lines().filter(|s| !s.is_empty()).collect();
        if !file_list.is_empty() {
            if run_cmd_silent("nixfmt", &file_list) {
                print_success("Nix files formatted.");
            } else {
                print_error("nixfmt formatting failed.");
                std::process::exit(1);
            }

            println!("-> Checking Nix formatting...");
            let mut check_args = vec!["-c"];
            check_args.extend(file_list);
            if run_cmd_silent("nixfmt", &check_args) {
                print_success("Nix formatting check passed.");
            } else {
                print_error("nixfmt formatting check failed.");
                std::process::exit(1);
            }
        }
    }

    println!("-> Formatting Lua files...");
    if run_cmd_silent(
        "nix-shell",
        &[
            "-p",
            "stylua",
            "--run",
            "find modules/features/wm/hyprland/hypr -type f -name '*.lua' -exec stylua {} +",
        ],
    ) {
        print_success("Lua files formatted.");
    } else {
        print_error("Lua formatting failed.");
        std::process::exit(1);
    }

    println!("-> Checking Lua formatting...");
    if run_cmd_silent(
        "nix-shell",
        &[
            "-p",
            "stylua",
            "--run",
            "find modules/features/wm/hyprland/hypr -type f -name '*.lua' -exec stylua --check {} +",
        ],
    ) {
        print_success("Lua formatting check passed.");
    } else {
        print_error("Lua formatting check failed.");
        std::process::exit(1);
    }

    // Step 5: Nix flake check
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

    // Step 6: Git clean check & commit formatting changes if any
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

    // Step 7: Nix Garbage Collection & Generation Cleanup
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

    // Step 8: System Rebuild
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
