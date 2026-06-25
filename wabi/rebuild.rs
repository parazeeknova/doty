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
            // Filter out untracked rebuild binary, rebuild.rs, and gitignores to keep things clean.
            let lines: Vec<&str> = status.lines()
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

    // Step 1: Lint, format, and build wabi
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

    // Step 2: Format QML, Nix, and Lua files
    print_step("Formatting and linting QML / Nix / Lua files...");
    
    println!("-> Formatting QML files...");
    if run_cmd_silent(
        "nix-shell",
        &["-p", "qt6.qtdeclarative", "--run", "find modules/features/wm/quickshell -type f -name '*.qml' -exec qmlformat -i {} +"]
    ) {
        print_success("QML files formatted.");
    } else {
        print_error("QML formatting failed.");
        std::process::exit(1);
    }

    println!("-> Linting QML files...");
    // We capture qmllint output and only treat non-zero exits as structural errors
    let qml_lint_output = Command::new("nix-shell")
        .args(&["-p", "qt6.qtdeclarative", "--run", "find modules/features/wm/quickshell -type f -name '*.qml' -exec qmllint {} +"])
        .output();
    match qml_lint_output {
        Ok(output) if output.status.success() => {
            print_success("QML lint passed.");
        }
        Ok(output) => {
            // It returned non-zero (meaning there were syntax errors)
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
    let nix_files_output = get_cmd_output("find", &[".", "-name", "*.nix", "-not", "-path", "./.git/*", "-not", "-path", "./wabi/*"]);
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
        &["-p", "stylua", "--run", "find modules/features/wm/hyprland/hypr -type f -name '*.lua' -exec stylua {} +"]
    ) {
        print_success("Lua files formatted.");
    } else {
        print_error("Lua formatting failed.");
        std::process::exit(1);
    }

    println!("-> Checking Lua formatting...");
    if run_cmd_silent(
        "nix-shell",
        &["-p", "stylua", "--run", "find modules/features/wm/hyprland/hypr -type f -name '*.lua' -exec stylua --check {} +"]
    ) {
        print_success("Lua formatting check passed.");
    } else {
        print_error("Lua formatting check failed.");
        std::process::exit(1);
    }

    // Step 3: Nix flake check
    print_step("Running nix flake check...");
    if run_cmd_silent("nix", &["flake", "check"]) {
        print_success("nix flake check passed.");
    } else {
        print_error("nix flake check failed.");
        std::process::exit(1);
    }

    // Step 4: Git clean check & commit formatting changes if any
    print_step("Checking for auto-formatting changes...");
    match get_cmd_output("git", &["status", "--porcelain"]) {
        Ok(status) => {
            let lines: Vec<&str> = status.lines()
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
                    && run_cmd_silent("git", &["commit", "--no-gpg-sign", "-m", "style: auto-format Nix, QML, and Lua files"]) {
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

    // Step 4.5: Nix Garbage Collection
    print_step("Collecting Nix garbage (deleting profiles older than 14 days)...");
    match run_cmd("sudo", &["nix-collect-garbage", "--delete-older-than", "14d"]) {
        Ok(status) if status.success() => print_success("Garbage collection completed successfully."),
        _ => print_warning("Garbage collection failed or skipped."),
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
