use wabi::{print_json, quickshell_dir};
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
struct VmSharedFolder {
    guest_name: String,
    host_path: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct VmSnapshotInfo {
    count: usize,
    last_time_ago: String,
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
    cpu_usage: f32,
    icon: String,
    shared_folders: Vec<VmSharedFolder>,
    snapshots: VmSnapshotInfo,
}

#[derive(Serialize, Deserialize, Debug)]
struct QemuVmInfo {
    name: String,
    uuid: String,
    state: String,
    running: bool,
    cpus: i64,
    ram_mb: i64,
    storage_bytes: u64,
    cpu_usage: f32,
    icon: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct VmListResult {
    vms: Vec<VmInfo>,
    qemu_vms: Vec<QemuVmInfo>,
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
    if lower.contains("windows") || lower.contains("win") || lower.contains("windholes") {
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

fn get_process_cpu_usage(search_pattern: &str) -> f32 {
    let Ok(pgrep_out) = Command::new("pgrep").args(["-f", search_pattern]).output() else {
        return 0.0;
    };
    if !pgrep_out.status.success() {
        return 0.0;
    }
    let pid_str = String::from_utf8_lossy(&pgrep_out.stdout);
    let first_pid = pid_str.lines().next().unwrap_or("").trim();
    if first_pid.is_empty() {
        return 0.0;
    }
    let Ok(ps_out) = Command::new("ps").args(["-p", first_pid, "-o", "%cpu"]).output() else {
        return 0.0;
    };
    if !ps_out.status.success() {
        return 0.0;
    }
    let ps_str = String::from_utf8_lossy(&ps_out.stdout);
    let val_str = ps_str.lines().nth(1).unwrap_or("0.0").trim();
    val_str.parse::<f32>().unwrap_or(0.0)
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

fn get_shared_folders(vmx: &Path) -> Vec<VmSharedFolder> {
    let mut folders = Vec::new();
    let log_path = vmx.parent().unwrap_or_else(|| Path::new(".")).join("vmware.log");
    if !log_path.exists() {
        return folders;
    }
    let Ok(log_text) = fs::read_to_string(&log_path) else {
        return folders;
    };

    use std::collections::HashMap;
    let mut guest_names: HashMap<String, String> = HashMap::new();
    let mut host_paths: HashMap<String, String> = HashMap::new();
    let mut enabled_status: HashMap<String, bool> = HashMap::new();

    for line in log_text.lines() {
        if line.contains("pref.sharedFolder") {
            let parts: Vec<&str> = line.split("pref.sharedFolder").collect();
            if parts.len() < 2 {
                continue;
            }
            let rest = parts[1];
            let index_and_prop = rest.split('=').next().unwrap_or("").trim();
            let value = rest.split('=').nth(1).unwrap_or("").trim().trim_matches('"');
            if index_and_prop.is_empty() || value.is_empty() {
                continue;
            }
            let index = index_and_prop.split('.').next().unwrap_or("").to_string();
            let prop = index_and_prop.split('.').nth(1).unwrap_or("");

            if prop == "guestName" {
                guest_names.insert(index, value.to_string());
            } else if prop == "hostPath" {
                host_paths.insert(index, value.to_string());
            } else if prop == "enabled" {
                enabled_status.insert(index, value.to_uppercase() == "TRUE");
            }
        }
    }

    for (index, guest_name) in guest_names {
        let host_path = host_paths.get(&index).cloned().unwrap_or_default();
        let enabled = enabled_status.get(&index).cloned().unwrap_or(true);
        if enabled && !host_path.is_empty() {
            folders.push(VmSharedFolder {
                guest_name,
                host_path,
            });
        }
    }

    folders
}

fn get_snapshots(vmx: &Path) -> VmSnapshotInfo {
    let mut count = 0;
    let mut latest_modified: Option<std::time::SystemTime> = None;
    let vmx_dir = vmx.parent().unwrap_or_else(|| Path::new("."));
    if let Ok(entries) = fs::read_dir(vmx_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() && path.extension().and_then(|e| e.to_str()) == Some("vmsn") {
                count += 1;
                if let Ok(meta) = fs::metadata(&path) {
                    if let Ok(mod_time) = meta.modified() {
                        if let Some(latest) = latest_modified {
                            if mod_time > latest {
                                latest_modified = Some(mod_time);
                            }
                        } else {
                            latest_modified = Some(mod_time);
                        }
                    }
                }
            }
        }
    }

    let last_time_ago = if let Some(mod_time) = latest_modified {
        if let Ok(elapsed) = std::time::SystemTime::now().duration_since(mod_time) {
            let secs = elapsed.as_secs();
            if secs < 60 {
                "just now".to_string()
            } else if secs < 3600 {
                format!("{}m ago", secs / 60)
            } else if secs < 86400 {
                format!("{}h ago", secs / 3600)
            } else {
                format!("{}d ago", secs / 86400)
            }
        } else {
            "unknown".to_string()
        }
    } else {
        "never".to_string()
    };

    VmSnapshotInfo {
        count,
        last_time_ago,
    }
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
    let mut guest_os = read_vmx_field(vmx, "guestOS").unwrap_or_default();
    if guest_os.is_empty() {
        if let Some(detailed_data) = read_vmx_field(vmx, "guestInfo.detailed.data") {
            if detailed_data.contains("prettyName='") {
                if let Some(pretty) = detailed_data.split("prettyName='").nth(1).and_then(|s| s.split('\'').next()) {
                    guest_os = pretty.to_string();
                }
            }
        }
    }

    let mut cpus = read_vmx_field(vmx, "numvcpus")
        .map(|s| parse_vmx_size(&s))
        .unwrap_or(0);
    let mut ram_mb = read_vmx_field(vmx, "memsize")
        .map(|s| parse_vmx_size(&s))
        .unwrap_or(0);

    let log_path = vmx.parent().unwrap_or_else(|| Path::new(".")).join("vmware.log");
    if (cpus == 0 || ram_mb == 0) && log_path.exists() {
        if let Ok(log_text) = fs::read_to_string(&log_path) {
            let mut total_ram = 0;
            for line in log_text.lines() {
                if cpus == 0 && line.contains("NumVCPUs ") {
                    if let Some(n) = line.split("NumVCPUs ").nth(1).and_then(|s| s.trim().split_whitespace().next()) {
                        cpus = n.parse().unwrap_or(0);
                    }
                }
                if line.contains("memoryHotplug: Node ") && line.contains("Present: ") {
                    if let Some(n) = line.split("Present: ").nth(1).and_then(|s| s.trim().split_whitespace().next()) {
                        if let Ok(val) = n.parse::<i64>() {
                            total_ram += val;
                        }
                    }
                }
            }
            if ram_mb == 0 && total_ram > 0 {
                if (total_ram + 1) % 1024 == 0 {
                    ram_mb = total_ram + 1;
                } else {
                    ram_mb = total_ram;
                }
            }
        }
    }

    let encrypted = read_vmx_field(vmx, "vmx.encryptionType").is_some()
        || read_vmx_field(vmx, "encryption.keySafe").is_some();

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

    if disks.is_empty() {
        let vmx_dir = vmx.parent().unwrap_or_else(|| Path::new("."));
        if let Ok(entries) = fs::read_dir(vmx_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_file() && path.extension().and_then(|e| e.to_str()) == Some("vmdk") {
                    let size = disk_size(&path);
                    storage_bytes += size;
                    disks.push(VmDisk {
                        path: path.to_string_lossy().to_string(),
                        size_bytes: size,
                    });
                }
            }
        }
    }

    let shared_folders = get_shared_folders(vmx);
    let snapshots = get_snapshots(vmx);

    let vmx_str = vmx.to_string_lossy().to_string();
    let is_running = running.iter().any(|r| r == &vmx_str);
    let icon = resolve_vm_icon(&guest_os).to_string();
    let cpu_usage = if is_running {
        get_process_cpu_usage(&vmx_str)
    } else {
        0.0
    };

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
        cpu_usage,
        icon,
        shared_folders,
        snapshots,
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

fn scan_qemu_vms() -> Vec<QemuVmInfo> {
    let mut out = Vec::new();
    let Ok(list_out) = Command::new("virsh").args(["-c", "qemu:///system", "list", "--all"]).output() else {
        return out;
    };
    if !list_out.status.success() {
        return out;
    }
    let stdout = String::from_utf8_lossy(&list_out.stdout);
    for line in stdout.lines().skip(2) {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        // Lines look like: " 1    win11      running" or " -    test       shut off"
        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.len() < 3 {
            continue;
        }
        let name = parts[1].to_string();
        let state = parts[2..].join(" ");
        let running = state == "running";
        let (cpus, ram_mb) = qemu_domain_resources(&name);
        let storage_bytes = qemu_domain_storage(&name);
        let icon = resolve_vm_icon(&name).to_string();
        let cpu_usage = if running {
            get_process_cpu_usage(&format!("guest={}", name))
        } else {
            0.0
        };
        out.push(QemuVmInfo {
            name,
            uuid: String::new(),
            state,
            running,
            cpus,
            ram_mb,
            storage_bytes,
            cpu_usage,
            icon,
        });
    }
    out
}

fn qemu_domain_storage(name: &str) -> u64 {
    let Ok(out) = Command::new("virsh")
        .args(["-c", "qemu:///system", "domblkinfo", name, "--all"])
        .output() else {
            return 0;
        };
    if !out.status.success() {
        return 0;
    }
    let text = String::from_utf8_lossy(&out.stdout);
    let mut total_bytes: u64 = 0;
    for line in text.lines().skip(2) {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.len() >= 2 {
            if let Ok(bytes) = parts[1].parse::<u64>() {
                total_bytes += bytes;
            }
        }
    }
    total_bytes
}

fn qemu_domain_resources(name: &str) -> (i64, i64) {
    let Ok(out) = Command::new("virsh").args(["-c", "qemu:///system", "dominfo", name]).output() else {
        return (0, 0);
    };
    if !out.status.success() {
        return (0, 0);
    }
    let text = String::from_utf8_lossy(&out.stdout);
    let mut cpus: i64 = 0;
    let mut ram_kib: i64 = 0;
    for line in text.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix("CPU(s):") {
            cpus = rest.trim().parse().unwrap_or(0);
        } else if let Some(rest) = trimmed.strip_prefix("Max memory:") {
            // "25165824 KiB"
            let mut parts = rest.trim().split_whitespace();
            if let Some(n) = parts.next() {
                ram_kib = n.parse().unwrap_or(0);
            }
        }
    }
    (cpus, ram_kib / 1024)
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
    let path = Path::new(vmx);
    read_vmx_field(path, "vmx.encryptionType").is_some()
        || read_vmx_field(path, "encryption.keySafe").is_some()
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
        "delete" => handle_delete(&args),
        "qemu-start" => handle_qemu_power(&args, "start"),
        "qemu-stop" => handle_qemu_power(&args, "shutdown"),
        "qemu-delete" => handle_qemu_delete(&args),
        other => {
            eprintln!("Unknown subcommand: {}", other);
            eprintln!(
                "Usage: get_vm_status [list|running|start|start-gui|stop|stop-hard|reset|screenshot|delete|qemu-start|qemu-stop|qemu-delete]"
            );
            std::process::exit(2);
        }
    }
}

fn emit_list() {
    let vms = scan_vms();
    let qemu_vms = scan_qemu_vms();
    print_json(&VmListResult { vms, qemu_vms });
}

fn handle_qemu_power(args: &[String], op: &str) {
    let Some(name) = args.get(2) else {
        eprintln!("Usage: get_vm_status qemu-{} <domain-name>", op);
        std::process::exit(2);
    };
    let output = Command::new("virsh")
        .args(["-c", "qemu:///system", op, name])
        .output()
        .map_err(|e| format!("virsh spawn failed: {}", e));
    match output {
        Ok(out) => {
            if !out.status.success() {
                let stderr = String::from_utf8_lossy(&out.stderr);
                eprintln!("virsh {} exited with code {}: {}",
                    op,
                    out.status.code().unwrap_or(-1),
                    if stderr.trim().is_empty() {
                        String::from_utf8_lossy(&out.stdout).into_owned()
                    } else {
                        stderr.into_owned()
                    });
            }
        }
        Err(e) => eprintln!("{}", e),
    }
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

fn guest_credentials_path() -> PathBuf {
    quickshell_dir().join("vm_popup/vm_guest_credentials")
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

    let is_qemu = !vmx.contains('/') && !vmx.ends_with(".vmx");
    if is_qemu {
        let Ok(out_res) = Command::new("virsh")
            .args(["-c", "qemu:///system", "screenshot", vmx, "--file", output])
            .output() else {
                eprintln!("Failed to run virsh screenshot");
                return;
            };
        if !out_res.status.success() {
            eprintln!("virsh screenshot failed: {}", String::from_utf8_lossy(&out_res.stderr));
        }
        return;
    }

    // Fallback to vmrun guest capture
    let mut full_args = vmrun_base_args(is_encrypted_vmx(vmx));
    if let Ok(creds) = fs::read_to_string(guest_credentials_path()) {
        let lines: Vec<&str> = creds.lines().collect();
        if lines.len() >= 2 {
            let user = lines[0].trim();
            let pass = lines[1].trim();
            if !user.is_empty() && !pass.is_empty() {
                full_args.push("-gu".to_string());
                full_args.push(user.to_string());
                full_args.push("-gp".to_string());
                full_args.push(pass.to_string());
            }
        }
    }
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

fn handle_delete(args: &[String]) {
    let Some(vmx) = args.get(2) else {
        eprintln!("Usage: get_vm_status delete <vmx-path>");
        std::process::exit(2);
    };

    let vmx_path = Path::new(vmx);
    if !vmx_path.exists() {
        eprintln!("VMX file not found: {}", vmx);
        std::process::exit(1);
    }

    // 1. If running, stop it
    let running = running_vms();
    let vmx_str = vmx_path.to_string_lossy().to_string();
    if running.iter().any(|r| r == &vmx_str) {
        let mut stop_args = vmrun_base_args(is_encrypted_vmx(vmx));
        stop_args.push("stop".to_string());
        stop_args.push(vmx.clone());
        stop_args.push("hard".to_string());
        let argv: Vec<&str> = stop_args.iter().map(String::as_str).collect();
        let _ = run_vmrun(&argv);
        std::thread::sleep(std::time::Duration::from_secs(3));
    }

    // 2. Nuke the folder (parent directory of the vmx)
    if let Some(parent) = vmx_path.parent() {
        let parent_canonical = parent.canonicalize().unwrap_or_else(|_| parent.to_path_buf());
        let root_canonical = Path::new(VM_SCAN_ROOT).canonicalize().unwrap_or_else(|_| PathBuf::from(VM_SCAN_ROOT));
        if parent_canonical.starts_with(&root_canonical) && parent_canonical != root_canonical {
            if let Err(e) = fs::remove_dir_all(&parent_canonical) {
                eprintln!("Failed to delete VM directory: {}", e);
                std::process::exit(1);
            }
        } else {
            eprintln!("Safety check failed: VM folder is outside scan root or matches scan root.");
            std::process::exit(1);
        }
    }
}

fn handle_qemu_delete(args: &[String]) {
    let Some(name) = args.get(2) else {
        eprintln!("Usage: get_vm_status qemu-delete <domain-name>");
        std::process::exit(2);
    };

    // 1. Force stop (destroy) the VM first
    let _ = Command::new("virsh")
        .args(["-c", "qemu:///system", "destroy", name])
        .output();

    // 2. Undefine VM and clean up all associated storage volumes
    let output = Command::new("virsh")
        .args(["-c", "qemu:///system", "undefine", name, "--remove-all-storage"])
        .output();

    if let Ok(out) = output {
        if !out.status.success() {
            let stderr = String::from_utf8_lossy(&out.stderr);
            eprintln!("Failed to delete QEMU VM: {}", stderr.trim());
            std::process::exit(1);
        }
    }
}
