use helpers_rs::{print_json, read_trimmed, run_cmd};
use serde::Serialize;
use std::fs::{self, File};
use std::io::{BufRead, BufReader};
use std::path::Path;
use std::thread::sleep;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[derive(Serialize)]
struct DiskInfo {
    name: String,
    read_rate: f64,
    write_rate: f64,
    total_gb: f64,
    used_gb: f64,
    free_gb: f64,
    usage_pct: i32,
}

#[derive(Serialize)]
struct SysmonStatus {
    cpu_name: String,
    cpu_usage: i32,
    cpu_temp: i32,
    cpu_freq: f64,
    cpu_power: f64,
    gpu_name: String,
    gpu_usage: i32,
    gpu_temp: i32,
    gpu_power: f64,
    gpu_mem_used: i32,
    gpu_mem_total: i32,
    ram_name: String,
    ram_speed: String,
    ram_total: f64,
    ram_used: f64,
    disk0: DiskInfo,
    disk1: DiskInfo,
}

fn read_cpu_times() -> Option<(u64, u64)> {
    let file = File::open("/proc/stat").ok()?;
    let reader = BufReader::new(file);
    for line in reader.lines() {
        let line = line.ok()?;
        if line.starts_with("cpu ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 5 {
                let user: u64 = parts[1].parse().unwrap_or(0);
                let nice: u64 = parts[2].parse().unwrap_or(0);
                let system: u64 = parts[3].parse().unwrap_or(0);
                let idle: u64 = parts[4].parse().unwrap_or(0);
                let iowait: u64 = parts[5].parse().unwrap_or(0);
                let irq: u64 = parts[6].parse().unwrap_or(0);
                let softirq: u64 = parts[7].parse().unwrap_or(0);
                let steal: u64 = parts[8].parse().unwrap_or(0);

                let total = user + nice + system + idle + iowait + irq + softirq + steal;
                let idle_total = idle + iowait;
                return Some((total, idle_total));
            }
        }
    }
    None
}

fn get_cpu_name() -> String {
    if let Ok(file) = File::open("/proc/cpuinfo") {
        let reader = BufReader::new(file);
        for line in reader.lines().flatten() {
            if line.starts_with("model name") {
                if let Some(pos) = line.find(':') {
                    let model = line[pos + 1..].trim();
                    if model.contains("i7-12700H") {
                        return "i7-12700H".to_string();
                    }
                    return model
                        .replace("Intel(R) Core(TM)", "")
                        .replace("12th Gen", "")
                        .replace("AMD", "")
                        .replace("Ryzen", "")
                        .replace("Processor", "")
                        .trim()
                        .to_string();
                }
            }
        }
    }
    "CPU".to_string()
}

fn get_cpu_usage() -> i32 {
    if let Some((total1, idle1)) = read_cpu_times() {
        sleep(Duration::from_millis(150));
        if let Some((total2, idle2)) = read_cpu_times() {
            let total_diff = total2.saturating_sub(total1);
            let idle_diff = idle2.saturating_sub(idle1);
            if total_diff > 0 {
                let usage = 100.0 * (total_diff - idle_diff) as f64 / total_diff as f64;
                return usage.round() as i32;
            }
        }
    }
    0
}

fn get_cpu_temp() -> i32 {
    for entry in std::fs::read_dir("/sys/class/thermal").ok().into_iter().flatten() {
        if let Ok(entry) = entry {
            let path = entry.path();
            if path.file_name().and_then(|n| n.to_str()).map_or(false, |n| n.starts_with("thermal_zone")) {
                let type_path = path.join("type");
                let temp_path = path.join("temp");
                if let Ok(type_str) = std::fs::read_to_string(type_path) {
                    let type_str = type_str.trim();
                    if type_str == "x86_pkg_temp" || type_str == "TCPU" {
                        if let Ok(temp_str) = std::fs::read_to_string(temp_path) {
                            if let Ok(temp_raw) = temp_str.trim().parse::<i32>() {
                                return temp_raw / 1000;
                            }
                        }
                    }
                }
            }
        }
    }
    if let Ok(temp_str) = std::fs::read_to_string("/sys/class/thermal/thermal_zone0/temp") {
        if let Ok(temp_raw) = temp_str.trim().parse::<i32>() {
            return temp_raw / 1000;
        }
    }
    0
}

fn get_cpu_freq() -> f64 {
    let mut sum = 0.0;
    let mut count = 0;
    if let Ok(file) = File::open("/proc/cpuinfo") {
        let reader = BufReader::new(file);
        for line in reader.lines().flatten() {
            if line.starts_with("cpu MHz") {
                if let Some(pos) = line.find(':') {
                    if let Ok(mhz) = line[pos + 1..].trim().parse::<f64>() {
                        sum += mhz;
                        count += 1;
                    }
                }
            }
        }
    }
    if count > 0 {
        sum / count as f64 / 1000.0 // return in GHz
    } else {
        0.0
    }
}

fn get_cpu_power(usage: i32) -> f64 {
    4.5 + (usage as f64 / 100.0) * 40.5
}

fn get_gpu_name() -> String {
    let out = run_cmd("nvidia-smi", &["--query-gpu=name", "--format=csv,noheader"])
        .unwrap_or_default();
    let name = out.trim();
    if name.contains("RTX 3060") {
        return "RTX 3060".to_string();
    }
    name.replace("NVIDIA GeForce", "")
        .replace("Laptop GPU", "")
        .replace("GPU", "")
        .trim()
        .to_string()
}

fn get_gpu_usage() -> i32 {
    let out = run_cmd(
        "nvidia-smi",
        &["--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"],
    )
    .unwrap_or_default();
    out.trim().parse::<i32>().unwrap_or(0)
}

fn get_gpu_temp() -> i32 {
    let out = run_cmd(
        "nvidia-smi",
        &["--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"],
    )
    .unwrap_or_default();
    out.trim().parse::<i32>().unwrap_or(0)
}

fn get_gpu_power() -> f64 {
    let out = run_cmd(
        "nvidia-smi",
        &["--query-gpu=power.draw", "--format=csv,noheader,nounits"],
    )
    .unwrap_or_default();
    out.trim().parse::<f64>().unwrap_or(0.0)
}

fn get_gpu_memory() -> (i32, i32) {
    let out = run_cmd(
        "nvidia-smi",
        &["--query-gpu=memory.used,memory.total", "--format=csv,noheader,nounits"],
    )
    .unwrap_or_default();
    let parts: Vec<&str> = out.split(',').collect();
    if parts.len() == 2 {
        let used = parts[0].trim().parse::<i32>().unwrap_or(0);
        let total = parts[1].trim().parse::<i32>().unwrap_or(0);
        return (used, total);
    }
    (0, 0)
}

fn parse_mem_line(line: &str) -> f64 {
    let parts: Vec<&str> = line.split_whitespace().collect();
    if parts.len() >= 2 {
        parts[1].parse::<f64>().unwrap_or(0.0) / 1024.0 / 1024.0 // return in GB
    } else {
        0.0
    }
}

fn get_ram_usage_info() -> (f64, f64) {
    let mut total = 0.0;
    let mut available = 0.0;
    if let Ok(file) = File::open("/proc/meminfo") {
        let reader = BufReader::new(file);
        for line in reader.lines().flatten() {
            if line.starts_with("MemTotal:") {
                total = parse_mem_line(&line);
            } else if line.starts_with("MemAvailable:") {
                available = parse_mem_line(&line);
            }
        }
    }
    let used = total - available;
    (total, used)
}

fn get_static_ram_info() -> (String, String) {
    let out = run_cmd("inxi", &["-m", "-c", "0"]).unwrap_or_default();
    let mut ram_type = "DDR".to_string();
    let mut speed = "N/A".to_string();
    for line in out.lines() {
        if line.contains("type:") {
            if let Some(pos) = line.find("type:") {
                let rest = &line[pos + 5..];
                if let Some(space_pos) = rest.trim().find(' ') {
                    ram_type = rest.trim()[..space_pos].trim().to_string();
                } else {
                    ram_type = rest.trim().to_string();
                }
            }
        }
        if line.contains("speed:") {
            if let Some(pos) = line.find("speed:") {
                speed = line[pos + 6..].trim().to_string();
            }
        }
    }
    (ram_type, speed)
}

// --- Disk helpers ---

const SECTOR_SIZE: u64 = 512;
const STAT_DIR: &str = "/tmp/.doty_disk_stats";

/// Read sectors_read (field 3) and sectors_written (field 7) from /sys/block/<dev>/stat
fn read_disk_sectors(dev: &str) -> Option<(u64, u64)> {
    let stat_path = format!("/sys/block/{dev}/stat");
    let content = fs::read_to_string(stat_path).ok()?;
    let fields: Vec<&str> = content.split_whitespace().collect();
    if fields.len() >= 7 {
        let sectors_read = fields[2].parse::<u64>().unwrap_or(0);
        let sectors_written = fields[6].parse::<u64>().unwrap_or(0);
        Some((sectors_read, sectors_written))
    } else {
        None
    }
}

fn now_nanos() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos() as u64
}

/// Compute read/write rates in MB/s by comparing current sectors with a previous snapshot.
fn disk_io_rates(dev: &str) -> (f64, f64) {
    let _ = fs::create_dir_all(STAT_DIR);
    let prev_file = format!("{STAT_DIR}/{dev}");
    let (sectors_read, sectors_written) = read_disk_sectors(dev).unwrap_or((0, 0));
    let now = now_nanos();

    let mut read_rate = 0.0;
    let mut write_rate = 0.0;

    if let Ok(content) = fs::read_to_string(&prev_file) {
        let lines: Vec<&str> = content.lines().collect();
        if lines.len() >= 3 {
            let prev_time: u64 = lines[0].parse().unwrap_or(0);
            let prev_read: u64 = lines[1].parse().unwrap_or(0);
            let prev_write: u64 = lines[2].parse().unwrap_or(0);
            let dt_ns = now.saturating_sub(prev_time);
            if dt_ns > 100_000_000 {
                // at least 100ms
                let dt_s = dt_ns as f64 / 1_000_000_000.0;
                let dr = sectors_read.saturating_sub(prev_read);
                let dw = sectors_written.saturating_sub(prev_write);
                read_rate = (dr as f64 * SECTOR_SIZE as f64) / (1024.0 * 1024.0) / dt_s;
                write_rate = (dw as f64 * SECTOR_SIZE as f64) / (1024.0 * 1024.0) / dt_s;
            }
        }
    }

    // Save current snapshot
    let snapshot = format!("{now}\n{sectors_read}\n{sectors_written}\n");
    let _ = fs::write(&prev_file, snapshot);

    (read_rate, write_rate)
}

/// Get disk usage (total, used, free in GB and usage%) via lsblk FSSIZE/FSUSED.
fn disk_usage(dev: &str) -> (f64, f64, f64, i32) {
    let output = run_cmd(
        "lsblk",
        &["-lnb", "-o", "FSSIZE,FSUSED", &format!("/dev/{dev}")],
    )
    .unwrap_or_default();

    let mut agg_total: u64 = 0;
    let mut agg_used: u64 = 0;
    let mut seen_totals: Vec<u64> = Vec::new();

    for line in output.lines() {
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() >= 2 {
            let fs_size: u64 = fields[0].parse().unwrap_or(0);
            let fs_used: u64 = fields[1].parse().unwrap_or(0);
            if fs_size == 0 {
                continue;
            }
            // Deduplicate btrfs subvolumes (they share the same pool, same FSSIZE)
            if seen_totals.contains(&fs_size) {
                continue;
            }
            seen_totals.push(fs_size);
            agg_total += fs_size;
            agg_used += fs_used;
        }
    }

    let gb = 1024.0 * 1024.0 * 1024.0;
    if agg_total > 0 {
        let total_gb = agg_total as f64 / gb;
        let used_gb = agg_used as f64 / gb;
        let free_gb = (agg_total - agg_used) as f64 / gb;
        let usage_pct = ((agg_used as f64 / agg_total as f64) * 100.0).round() as i32;
        (total_gb, used_gb, free_gb, usage_pct)
    } else {
        // Fallback: raw disk size
        let raw = read_trimmed(Path::new(&format!("/sys/block/{dev}/size")))
            .and_then(|s| s.parse::<u64>().ok())
            .unwrap_or(0);
        let total_gb = (raw * SECTOR_SIZE) as f64 / gb;
        (total_gb, 0.0, total_gb, 0)
    }
}

fn get_disk_name(dev: &str) -> String {
    read_trimmed(Path::new(&format!("/sys/block/{dev}/device/model")))
        .unwrap_or_else(|| dev.to_string())
}

fn get_disk_info(dev: &str) -> DiskInfo {
    let name = get_disk_name(dev);
    let (read_rate, write_rate) = disk_io_rates(dev);
    let (total_gb, used_gb, free_gb, usage_pct) = disk_usage(dev);
    DiskInfo {
        name,
        read_rate: (read_rate * 10.0).round() / 10.0,
        write_rate: (write_rate * 10.0).round() / 10.0,
        total_gb: (total_gb * 10.0).round() / 10.0,
        used_gb: (used_gb * 10.0).round() / 10.0,
        free_gb: (free_gb * 10.0).round() / 10.0,
        usage_pct,
    }
}

fn main() {
    let cpu_n = get_cpu_name();
    let cpu = get_cpu_usage();
    let cpu_t = get_cpu_temp();
    let cpu_f = get_cpu_freq();
    let cpu_p = get_cpu_power(cpu);
    let gpu_n = get_gpu_name();
    let gpu = get_gpu_usage();
    let gpu_t = get_gpu_temp();
    let gpu_p = get_gpu_power();
    let (gpu_mem_u, gpu_mem_t) = get_gpu_memory();
    let (ram_tot, ram_usd) = get_ram_usage_info();
    let (ram_name, ram_speed) = get_static_ram_info();
    let disk0 = get_disk_info("nvme0n1");
    let disk1 = get_disk_info("nvme1n1");

    let status = SysmonStatus {
        cpu_name: cpu_n,
        cpu_usage: cpu,
        cpu_temp: cpu_t,
        cpu_freq: cpu_f,
        cpu_power: cpu_p,
        gpu_name: gpu_n,
        gpu_usage: gpu,
        gpu_temp: gpu_t,
        gpu_power: gpu_p,
        gpu_mem_used: gpu_mem_u,
        gpu_mem_total: gpu_mem_t,
        ram_name,
        ram_speed,
        ram_total: ram_tot,
        ram_used: ram_usd,
        disk0,
        disk1,
    };
    print_json(&status);
}
