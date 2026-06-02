use helpers_rs::{print_json, quickshell_dir};
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const VM_SCAN_ROOT: &str = "/run/media/parazeeknova/clips/VM";

#[derive(Serialize, Deserialize, Debug)]
struct VmDisk {
    path: String,
    size_bytes: u64,
}

#[derive(Serialize, Deserialize, Debug)]
struct VmInfo {
    name: String,
    vmx: String,
    guest_os: String,
    cpus: i64,
    ram_mb: i64,
    disks: Vec<VmDisk>,
    storage_bytes: u64,
    encrypted: bool,
    running: bool,
    icon: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct VmListResult {
    vms: Vec<VmInfo>,
}

fn password_path() -> PathBuf {
    quickshell_dir().join("vm_popup/vm_password")
}

fn read_vmx_field(vmx: &Path, key: &str) -> Option<String> {
    let text = fs::read_to_string(vmx).ok()?;
    for line in text.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix(key) {
            let rest = rest.trim_start();
            if let Some(value) = rest.strip_prefix('=') {
                let value = value.trim();
                let unquoted = value
                    .strip_prefix('"')
                    .and_then(|s| s.strip_suffix('"'))
                    .unwrap_or(value);
                return Some(unquoted.to_string());
            }
        }
    }
    None
}

fn parse_vmx_size(value: &str) -> i64 {
    value.parse::<i64>().unwrap_or(0)
}

fn disk_size(path: &Path) -> u64 {
    let Ok(meta) = fs::metadata(path) else {
        return 0;
    };
    meta.len()
}

fn resolve_vm_icon(guest_os: &str) -> &'static str {
    let lower = guest_os.to_lowercase();
    if lower.contains("windows") {
        "\u{e70f}" // nf-dev-windows
    } else if lower.contains("darwin") || lower.contains("macos") {
        "\u{f179}" // nf-md-apple
    } else if lower.contains("ubuntu") {
        "\u{f31b}" // nf-md-ubuntu
    } else if lower.contains("debian") {
        "\u{f306}" // nf-md-debian
    } else if lower.contains("fedora") {
        "\u{f30a}" // nf-md-fedora
    } else if lower.contains("arch") {
        "\u{f303}" // nf-md-arch
    } else if lower.contains("redhat") || lower.contains("rhel") || lower.contains("centos") {
        "\u{f316}" // nf-md-redhat
    } else if lower.contains("linux") {
        "\u{f31c}" // nf-md-linux
    } else if lower.contains("freebsd") {
        "\u{f30c}" // nf-md-freebsd
    } else if lower.contains("vmware") || lower.contains("photon") {
        "\u{f1ba}" // nf-md-server
    } else {
        "\u{f45c}" // nf-md-monitor
    }
}

fn resolve_disk_paths(vmx: &Path) -> Vec<PathBuf> {
    let mut disks = Vec::new();
    let text = match fs::read_to_string(vmx) {
        Ok(t) => t,
        Err(_) => return disks,
    };

    let vmx_dir = vmx.parent().unwrap_or_else(|| Path::new("."));
    for line in text.lines() {
        let trimmed = line.trim();
        // Match scsi0:0.fileName / nvme0:0.fileName / sata0:0.fileName patterns
        let is_disk_line = trimmed.contains(".fileName = ")
            && (trimmed.starts_with("scsi")
                || trimmed.starts_with("nvme")
                || trimmed.starts_with("sata")
                || trimmed.starts_with("ide"));
        if !is_disk_line {
            continue;
        }
        // Only include the first slot of each controller (sata0:0, sata1:0, ...)
        // higher slots are typically CD-ROM/ISO devices.
        if let Some(key) = trimmed.split('=').next() {
            let key = key.trim();
            if let Some(slot) = key.split('.').next()
                && slot.matches(':').count() > 0
                && !slot.ends_with(":0")
            {
                continue;
            }
        }
        if let Some(rest) = trimmed.split('=').nth(1) {
            let value = rest.trim().trim_matches('"');
            if value.is_empty() || value == "-1" {
                continue;
            }
            // Skip CD-ROM images
            if value.to_lowercase().ends_with(".iso")
                || value.to_lowercase().ends_with(".cdr")
            {
                continue;
            }
            let path = PathBuf::from(value);
            let resolved = if path.is_absolute() {
                path
            } else {
                vmx_dir.join(path)
            };
            if resolved.exists() && !disks.contains(&resolved) {
                disks.push(resolved);
            }
        }
    }
    disks
}

fn scan_vms() -> Vec<VmInfo> {
    let mut vms = Vec::new();
    let running = running_vms();
    let scan_root = Path::new(VM_SCAN_ROOT);

    if !scan_root.exists() {
        return vms;
    }

    let Ok(entries) = fs::read_dir(scan_root) else {
        return vms;
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file() && path.extension().and_then(|e| e.to_str()) == Some("vmx") {
            if let Some(vm) = build_vm_info(&path, &running) {
                vms.push(vm);
            }
        } else if path.is_dir() {
            collect_vmx_recursive(&path, &running, &mut vms);
        }
    }
    vms
}

fn collect_vmx_recursive(dir: &Path, running: &[String], out: &mut Vec<VmInfo>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            collect_vmx_recursive(&path, running, out);
        } else if path.extension().and_then(|e| e.to_str()) == Some("vmx")
            && let Some(vm) = build_vm_info(&path, running)
        {
            out.push(vm);
        }
    }
}

fn build_vm_info(vmx: &Path, running: &[String]) -> Option<VmInfo> {
    let display_name =
        read_vmx_field(vmx, "displayName").unwrap_or_else(|| {
            vmx.file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("unknown")
                .to_string()
        });
    let guest_os = read_vmx_field(vmx, "guestOS").unwrap_or_default();
    let cpus = read_vmx_field(vmx, "numvcpus")
        .map(|s| parse_vmx_size(&s))
        .unwrap_or(0);
    let ram_mb = read_vmx_field(vmx, "memsize")
        .map(|s| parse_vmx_size(&s))
        .unwrap_or(0);

    let encryption_type = read_vmx_field(vmx, "vmx.encryptionType").unwrap_or_default();
    let encrypted = !encryption_type.is_empty();

    let disk_paths = resolve_disk_paths(vmx);
    let mut disks = Vec::new();
    let mut storage_bytes: u64 = 0;
    for path in &disk_paths {
        let size = disk_size(path);
        storage_bytes += size;
        disks.push(VmDisk {
            path: path.to_string_lossy().to_string(),
            size_bytes: size,
        });
    }

    let vmx_str = vmx.to_string_lossy().to_string();
    let is_running = running.iter().any(|r| r == &vmx_str);
    let icon = resolve_vm_icon(&guest_os).to_string();

    Some(VmInfo {
        name: display_name,
        vmx: vmx_str,
        guest_os,
        cpus,
        ram_mb,
        disks,
        storage_bytes,
        encrypted,
        running: is_running,
        icon,
    })
}

fn running_vms() -> Vec<String> {
    let Ok(out) = Command::new("vmrun").arg("list").output() else {
        return Vec::new();
    };
    if !out.status.success() {
        return Vec::new();
    }
    String::from_utf8_lossy(&out.stdout)
        .lines()
        .filter_map(|line| {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with("Total") {
                return None;
            }
            Some(trimmed.to_string())
        })
        .collect()
}

fn vmrun_base_args(encrypted: bool) -> Vec<String> {
    let mut args = vec!["-T".to_string(), "ws".to_string()];
    if encrypted
        && let Ok(pw) = fs::read_to_string(password_path())
    {
        let trimmed = pw.trim();
        if !trimmed.is_empty() {
            args.push("-vp".to_string());
            args.push(trimmed.to_string());
        }
    }
    args
}

fn is_encrypted_vmx(vmx: &str) -> bool {
    read_vmx_field(Path::new(vmx), "vmx.encryptionType")
        .map(|s| !s.is_empty())
        .unwrap_or(false)
}

fn run_vmrun(args: &[&str]) -> Result<String, String> {
    let output = Command::new("vmrun")
        .args(args)
        .output()
        .map_err(|e| format!("vmrun spawn failed: {}", e))?;
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    if !output.status.success() {
        return Err(format!(
            "vmrun exited with code {}: {}",
            output.status.code().unwrap_or(-1),
            if stderr.trim().is_empty() { stdout } else { stderr }
        ));
    }
    Ok(stdout)
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        emit_list();
        return;
    }

    match args[1].as_str() {
        "list" | "status" => emit_list(),
        "running" => {
            let running = running_vms();
            print_json(&serde_json::json!({ "running": running }));
        }
        "start" => handle_power(&args, "start", &["nogui"]),
        "start-gui" => handle_power(&args, "start", &[]),
        "stop" => handle_power(&args, "stop", &["soft"]),
        "stop-hard" => handle_power(&args, "stop", &["hard"]),
        "reset" => handle_power(&args, "reset", &["soft"]),
        "screenshot" => handle_screenshot(&args),
        other => {
            eprintln!("Unknown subcommand: {}", other);
            eprintln!(
                "Usage: get_vm_status [list|running|start|start-gui|stop|stop-hard|reset|screenshot]"
            );
            std::process::exit(2);
        }
    }
}

fn emit_list() {
    let vms = scan_vms();
    print_json(&VmListResult { vms });
}

fn handle_power(args: &[String], op: &str, mode: &[&str]) {
    let Some(vmx) = args.get(2) else {
        eprintln!("Usage: get_vm_status {} <vmx-path>", op);
        std::process::exit(2);
    };
    let mut full_args = vmrun_base_args(is_encrypted_vmx(vmx));
    full_args.push(op.to_string());
    full_args.push(vmx.clone());
    for m in mode {
        full_args.push((*m).to_string());
    }
    let argv: Vec<&str> = full_args.iter().map(String::as_str).collect();
    match run_vmrun(&argv) {
        Ok(out) => {
            if !out.trim().is_empty() {
                println!("{}", out.trim());
            }
        }
        Err(e) => eprintln!("{}", e),
    }
}

fn handle_screenshot(args: &[String]) {
    let Some(vmx) = args.get(2) else {
        eprintln!("Usage: get_vm_status screenshot <vmx-path> <output-png>");
        std::process::exit(2);
    };
    let Some(output) = args.get(3) else {
        eprintln!("Usage: get_vm_status screenshot <vmx-path> <output-png>");
        std::process::exit(2);
    };

    if let Some(parent) = Path::new(output).parent() {
        let _ = fs::create_dir_all(parent);
    }

    let mut full_args = vmrun_base_args(is_encrypted_vmx(vmx));
    full_args.push("captureScreen".to_string());
    full_args.push(vmx.clone());
    full_args.push(output.clone());
    let argv: Vec<&str> = full_args.iter().map(String::as_str).collect();
    match run_vmrun(&argv) {
        Ok(out) => {
            if !out.trim().is_empty() {
                println!("{}", out.trim());
            }
        }
        Err(e) => eprintln!("{}", e),
    }
}
