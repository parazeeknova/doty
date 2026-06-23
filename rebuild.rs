use std::process::{Command, ExitStatus};

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

fn run_cmd_in_dir(cmd: &str, args: &[&str], dir: &str) -> std::io::Result<ExitStatus> {
    Command::new(cmd)
        .args(args)
        .current_dir(dir)
        .status()
}

fn run_cmd(cmd: &str, args: &[&str]) -> std::io::Result<ExitStatus> {
    Command::new(cmd)
        .args(args)
        .status()
}

fn get_cmd_output(cmd: &str, args: &[&str]) -> std::io::Result<String> {
    let output = Command::new(cmd)
        .args(args)
        .output()?;
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn main() {
    print_header("Starting Rust-powered Rebuild Pipeline");

    // Step 0: Check Git Working Directory status
    print_step("Checking Git working tree status...");
    match get_cmd_output("git", &["status", "--porcelain"]) {
        Ok(status) => {
            // Ignore the 'rebuild' binary itself or rebuild.rs if untracked, but let's be safe.
            // If there are other files modified or untracked:
            let lines: Vec<&str> = status.lines()
                .filter(|line| {
                    let trim_line = line.trim();
                    !trim_line.is_empty() && !trim_line.ends_with("rebuild") && !trim_line.ends_with("rebuild.rs")
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

    // Step 1: Lint, format, and build wabi
    print_step("Linting, formatting, and building wabi...");
    
    println!("-> wabi: cargo clippy --all-targets -- -D warnings");
    match run_cmd_in_dir("cargo", &["clippy", "--all-targets", "--", "-D", "warnings"], "wabi") {
        Ok(status) if status.success() => print_success("wabi clippy passed."),
        _ => {
            print_error("wabi clippy failed.");
            std::process::exit(1);
        }
    }

    println!("-> wabi: cargo fmt --all");
    match run_cmd_in_dir("cargo", &["fmt", "--all", "--", "--check"], "wabi") {
        Ok(status) if status.success() => print_success("wabi formatting is correct."),
        _ => {
            print_error("wabi formatting check failed. Run 'cargo fmt --all' in wabi directory.");
            std::process::exit(1);
        }
    }

    println!("-> wabi: cargo build --release + make install");
    match run_cmd_in_dir("cargo", &["build", "--release"], "wabi") {
        Ok(status) if status.success() => {},
        _ => {
            print_error("wabi build failed.");
            std::process::exit(1);
        }
    }
    match run_cmd_in_dir("make", &["install"], "wabi") {
        Ok(status) if status.success() => print_success("wabi built and installed successfully."),
        _ => {
            print_error("wabi install failed.");
            std::process::exit(1);
        }
    }

    // Step 2: Format QML files and run nixfmt
    print_step("Formatting and linting QML / Nix files...");
    
    println!("-> Formatting QML files...");
    let qml_format_status = run_cmd(
        "nix-shell",
        &["-p", "qt6.qtdeclarative", "--run", "find modules/features/wm/quickshell -name '*.qml' -exec qmlformat -i {} +"]
    );
    if qml_format_status.is_err() || !qml_format_status.unwrap().success() {
        print_error("QML formatting failed.");
        std::process::exit(1);
    }

    println!("-> Linting QML files...");
    let qml_lint_status = run_cmd(
        "nix-shell",
        &["-p", "qt6.qtdeclarative", "--run", "find modules/features/wm/quickshell -name '*.qml' -exec qmllint {} +"]
    );
    if qml_lint_status.is_err() || !qml_lint_status.unwrap().success() {
        print_warning("QML lint exited with non-zero or warning, but proceeding.");
    }

    println!("-> Formatting Nix files...");
    let nix_files_output = get_cmd_output("find", &[".", "-name", "*.nix", "-not", "-path", "./.git/*", "-not", "-path", "./wabi/*"]);
    if let Ok(files) = nix_files_output {
        let file_list: Vec<&str> = files.lines().filter(|s| !s.is_empty()).collect();
        if !file_list.is_empty() {
            let mut args = file_list.clone();
            let format_status = Command::new("nixfmt").args(&args).status();
            if format_status.is_err() || !format_status.unwrap().success() {
                print_error("nixfmt formatting failed.");
                std::process::exit(1);
            }

            println!("-> Checking Nix formatting...");
            let mut check_args = vec!["-c"];
            check_args.extend(file_list);
            let check_status = Command::new("nixfmt").args(&check_args).status();
            if check_status.is_err() || !check_status.unwrap().success() {
                print_error("nixfmt formatting check failed.");
                std::process::exit(1);
            }
        }
    }
    print_success("QML and Nix formatting / linting completed.");

    // Step 3: Nix flake check
    print_step("Running nix flake check...");
    match run_cmd("nix", &["flake", "check"]) {
        Ok(status) if status.success() => print_success("nix flake check passed."),
        _ => {
            print_error("nix flake check failed.");
            std::process::exit(1);
        }
    }

    // Step 4: Git clean check & commit formatting changes if any
    print_step("Checking for auto-formatting changes...");
    match get_cmd_output("git", &["status", "--porcelain"]) {
        Ok(status) => {
            let lines: Vec<&str> = status.lines()
                .filter(|line| {
                    let trim_line = line.trim();
                    !trim_line.is_empty() && !trim_line.ends_with("rebuild") && !trim_line.ends_with("rebuild.rs")
                })
                .collect();

            if !lines.is_empty() {
                print_warning("Formatting changed some files. Committing formatting updates...");
                if run_cmd("git", &["add", "-A"]).is_ok() 
                    && run_cmd("git", &["commit", "--no-gpg-sign", "-m", "style: auto-format Nix and QML files"]).is_ok() {
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

    // Step 5: System Rebuild
    print_step("Rebuilding NixOS configuration...");
    match run_cmd("sudo", &["nixos-rebuild", "switch", "--flake", ".#apostrophe"]) {
        Ok(status) if status.success() => print_success("\n=== Rebuild Pipeline Completed Successfully ==="),
        _ => {
            print_error("NixOS rebuild switch failed.");
            std::process::exit(1);
        }
    }
}
