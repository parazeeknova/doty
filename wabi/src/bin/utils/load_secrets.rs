use std::collections::HashMap;
use std::env;
use std::fs;
use std::os::unix::process::CommandExt;
use std::process::Command;

fn get_secrets() -> HashMap<&'static str, String> {
    let mut map = HashMap::new();

    let secret_mappings = [
        ("OPENROUTER_API_KEY", "/run/secrets/openrouter-api-key"),
        ("CONTEXT7_API_KEY", "/run/secrets/context7-api-key"),
        ("GITHUB_PERSONAL_ACCESS_TOKEN", "/run/secrets/github-token"),
        ("TINYFISH_API_KEY", "/run/secrets/tinyfish-api-key"),
        ("MERGE_GATEWAY_API_KEY", "/run/secrets/merge-gateway-api-key"),
        ("ANTHROPIC_API_KEY", "/run/secrets/anthropic-api-key"),
        ("MODAL_API_KEY", "/run/secrets/modal-api-key"),
        ("GEMINI_API_KEY", "/run/secrets/gemini-api-key"),
    ];

    for (var_name, path) in secret_mappings {
        if let Ok(content) = fs::read_to_string(path) {
            let val = content.trim().to_string();
            if !val.is_empty() {
                map.insert(var_name, val);
            }
        }
    }

    let home = env::var("HOME").unwrap_or_else(|_| "/home/parazeeknova".to_string());
    let supermemory_key = fs::read_to_string("/run/secrets/supermemory-api-key")
        .or_else(|_| fs::read_to_string(format!("{}/.supermemory/api-key", home)))
        .map(|s| s.trim().to_string())
        .ok();

    let supermemory_codex_key = fs::read_to_string("/run/secrets/supermemory-codex-api-key")
        .map(|s| s.trim().to_string())
        .ok()
        .or_else(|| supermemory_key.clone());

    if let Some(ref key) = supermemory_key {
        map.insert("SUPERMEMORY_API_KEY", key.clone());
        map.insert("SUPERMEMORY_CC_API_KEY", key.clone());
    }
    if let Some(key) = supermemory_codex_key {
        map.insert("SUPERMEMORY_CODEX_API_KEY", key);
    }

    map.insert("SUPERMEMORY_BASE_URL", "http://localhost:6767".to_string());
    map.insert("SUPERMEMORY_API_URL", "http://localhost:6767".to_string());
    map.insert("STRIX_LLM", "openai/deepseek/deepseek-v4-flash".to_string());
    map.insert("LLM_API_BASE", "https://api-gateway.merge.dev/v1/openai".to_string());
    map.insert("OPENAI_BASE_URL", "https://api-gateway.merge.dev/v1/openai".to_string());

    map
}

fn import_to_systemd(secrets: &HashMap<&str, String>) {
    let mut cmd = Command::new("systemctl");
    cmd.arg("--user").arg("import-environment");
    for (k, v) in secrets {
        cmd.arg(format!("{k}={v}"));
    }
    match cmd.status() {
        Ok(status) if status.success() => {
            eprintln!("Successfully imported {} secrets to systemd --user", secrets.len());
        }
        Ok(status) => {
            eprintln!("systemctl exited with status: {status}");
        }
        Err(e) => {
            eprintln!("Failed to execute systemctl: {e}");
        }
    }
}

fn print_sh_exports(secrets: &HashMap<&str, String>) {
    for (k, v) in secrets {
        // Escape single quotes for POSIX sh
        let escaped = v.replace('\'', "'\\''");
        println!("export {k}='{escaped}';");
    }
}

fn print_fish_exports(secrets: &HashMap<&str, String>) {
    for (k, v) in secrets {
        let escaped = v.replace('\\', "\\\\").replace('\'', "\\'");
        println!("set -gx {k} '{escaped}';");
    }
}

fn exec_command(cmd_name: &str, args: &[String], secrets: &HashMap<&str, String>) {
    let mut cmd = Command::new(cmd_name);
    cmd.args(args);
    for (k, v) in secrets {
        cmd.env(k, v);
    }
    let err = cmd.exec();
    eprintln!("Failed to execute {cmd_name}: {err}");
    std::process::exit(1);
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let secrets = get_secrets();

    if args.is_empty() {
        print_sh_exports(&secrets);
        return;
    }

    match args[0].as_str() {
        "--import-systemd" | "-s" => {
            import_to_systemd(&secrets);
        }
        "--fish" => {
            print_fish_exports(&secrets);
        }
        "--sh" | "--export" => {
            print_sh_exports(&secrets);
        }
        "exec" | "run" => {
            if args.len() < 2 {
                eprintln!("Usage: load_secrets exec <command> [args...]");
                std::process::exit(1);
            }
            exec_command(&args[1], &args[2..], &secrets);
        }
        "-h" | "--help" => {
            println!("load_secrets - Secrets and environment loader for Wabi / Doty");
            println!();
            println!("Usage:");
            println!("  load_secrets                    Print POSIX shell export statements (eval $(load_secrets))");
            println!("  load_secrets --import-systemd   Import all decrypted secrets into systemctl --user");
            println!("  load_secrets --fish             Print fish shell set -gx statements");
            println!("  load_secrets exec <cmd> [args]  Execute a command directly with all secrets in env");
        }
        _ => {
            // If unknown option or command, execute it directly if not starting with '-'
            if !args[0].starts_with('-') {
                exec_command(&args[0], &args[1..], &secrets);
            } else {
                eprintln!("Unknown argument: {}. Try --help", args[0]);
                std::process::exit(1);
            }
        }
    }
}
