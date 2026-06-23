use serde::Serialize;
use std::collections::HashSet;
use std::process::Command;
use wabi::print_json;

#[derive(Serialize, Clone)]
struct PortEntry {
    protocol: String,
    port: String,
    process: String,
    pid: String,
    address: String,
    peer: String,
}

#[derive(Serialize)]
struct PortsStatus {
    ports: Vec<PortEntry>,
}

fn main() {
    let output = match Command::new("ss").args(["-tulpn"]).output() {
        Ok(out) => String::from_utf8_lossy(&out.stdout).into_owned(),
        Err(_) => {
            print_json(&PortsStatus { ports: vec![] });
            return;
        }
    };

    let mut seen = HashSet::new();
    let mut ports = Vec::new();

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
        let peer = if parts.len() > 5 { parts[5] } else { "*:*" };
        let port = local_addr.split(':').next_back().unwrap_or("");
        let bind_addr = local_addr
            .rsplit_once(':')
            .map(|(a, _)| a)
            .unwrap_or(local_addr);

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
                            ports.push(PortEntry {
                                protocol: proto.clone(),
                                port: port.to_string(),
                                process: prog.to_string(),
                                pid: pid.to_string(),
                                address: bind_addr.to_string(),
                                peer: peer.to_string(),
                            });
                        }
                    }
                }
                cursor = &cursor[pid_idx + 4..];
            }
        }
    }

    print_json(&PortsStatus { ports });
}
