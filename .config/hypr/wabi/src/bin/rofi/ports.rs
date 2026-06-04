use std::collections::HashSet;
use std::env;
use std::process::Command;

fn notify(title: &str, msg: &str) {
    let _ = Command::new("notify-send").args([title, msg]).status();
}

fn main() {
    let retv = env::var("ROFI_RETV").unwrap_or_default();
    let info = env::var("ROFI_INFO").unwrap_or_default();

    if retv == "1" && !info.is_empty() {
        if let Ok(pid) = info.parse::<i32>() {
            let status = Command::new("kill").args(["-9", &pid.to_string()]).status();
            match status {
                Ok(s) if s.success() => {
                    notify("Ports Rofi", &format!("Killed process with PID {}", pid));
                }
                _ => {
                    notify(
                        "Ports Rofi",
                        &format!("Failed to kill process with PID {}", pid),
                    );
                }
            }
        } else {
            notify("Ports Rofi", &format!("Invalid PID: {}", info));
        }
        std::process::exit(0);
    }

    let output = match Command::new("ss").args(["-tulpn"]).output() {
        Ok(out) => String::from_utf8_lossy(&out.stdout).into_owned(),
        Err(e) => {
            eprintln!("Error running ss: {}", e);
            std::process::exit(1);
        }
    };

    let mut seen = HashSet::new();

    for line in output.lines().skip(1) {
        if !line.contains("users:(") {
            continue;
        }

        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 5 {
            continue;
        }

        let proto = parts[0].to_uppercase();
        let local_addr = parts[4];
        let port = local_addr.split(':').next_back().unwrap_or("");

        if let Some(users_idx) = line.find("users:(") {
            let users_part = &line[users_idx..];

            let mut cursor = users_part;
            while let Some(pid_idx) = cursor.find("pid=") {
                let pre_pid = &cursor[..pid_idx];
                if let Some(first_quote) = pre_pid.rfind('"') {
                    let pre_quote = &pre_pid[..first_quote];
                    if let Some(second_quote) = pre_quote.rfind('"') {
                        let prog = &pre_quote[second_quote + 1..first_quote];

                        let after_pid = &cursor[pid_idx + 4..];
                        let end_pid_idx = after_pid
                            .find(',')
                            .unwrap_or_else(|| after_pid.find(')').unwrap_or(0));
                        let pid = &after_pid[..end_pid_idx];

                        let key = (
                            proto.clone(),
                            port.to_string(),
                            prog.to_string(),
                            pid.to_string(),
                        );
                        if !seen.contains(&key) {
                            seen.insert(key.clone());
                            let label =
                                format!("[{}] Port {} -> {} (PID {})", proto, port, prog, pid);
                            println!("{}\0info\x1f{}", label, pid);
                        }
                    }
                }
                cursor = &cursor[pid_idx + 4..];
            }
        }
    }

    println!("\0message\x1fSelect a port to kill\n");
}
