use serde::{Deserialize, Serialize};
use std::fs;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelInfo {
    pub id: String,
    pub name: String,
    pub model_type: String, // "qwen-image-2.1" | "sdxl" | "sd15" | "flux" | "generic"
    pub diffusion_path: PathBuf,
    pub vae_path: Option<PathBuf>,
    pub llm_path: Option<PathBuf>,
    pub default_steps: u32,
    pub default_cfg: f32,
    pub default_sampler: String,
    pub default_width: u32,
    pub default_height: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SdGenState {
    pub last_model: String,
    pub last_model_path: String,
    pub last_run_timestamp: u64,
    pub last_load_ms: u64,
    pub last_sample_ms: u64,
    pub last_total_ms: u64,
    pub last_output: String,
    pub is_cold: bool,
    pub steps: u32,
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "event")]
pub enum ProgressEvent {
    #[serde(rename = "start")]
    Start {
        model: String,
        prompt: String,
        is_cold_candidate: bool,
    },
    #[serde(rename = "loading")]
    Loading { model: String, elapsed_ms: u64 },
    #[serde(rename = "loaded")]
    Loaded {
        model: String,
        load_ms: u64,
        is_cold: bool,
    },
    #[serde(rename = "step")]
    Step {
        step: u32,
        total_steps: u32,
        percent: u32,
        elapsed_ms: u64,
    },
    #[serde(rename = "complete")]
    Complete {
        status: String,
        output_path: String,
        model: String,
        is_cold_start: bool,
        load_duration_ms: u64,
        sample_duration_ms: u64,
        total_duration_ms: u64,
        steps: u32,
        width: u32,
        height: u32,
        cfg: f32,
        prompt: String,
        seed: i64,
    },
    #[serde(rename = "error")]
    Error { error: String },
}

#[derive(Debug, Default)]
struct CliArgs {
    command: Option<String>,
    prompt: Option<String>,
    negative_prompt: Option<String>,
    model: Option<String>,
    vae: Option<PathBuf>,
    llm: Option<PathBuf>,
    output: Option<PathBuf>,
    steps: Option<u32>,
    cfg: Option<f32>,
    sampler: Option<String>,
    width: Option<u32>,
    height: Option<u32>,
    seed: Option<i64>,
    offload_to_cpu: Option<bool>,
    flash_attention: Option<bool>,
    json: bool,
    notify: bool,
    verbose: bool,
}

fn home_dir() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn cache_dir() -> PathBuf {
    home_dir().join(".cache").join("sd_gen")
}

fn state_file_path() -> PathBuf {
    cache_dir().join("state.json")
}

fn load_last_state() -> Option<SdGenState> {
    let path = state_file_path();
    let data = fs::read_to_string(path).ok()?;
    serde_json::from_str(&data).ok()
}

fn save_state(state: &SdGenState) {
    let dir = cache_dir();
    let _ = fs::create_dir_all(&dir);
    let path = state_file_path();
    if let Ok(json) = serde_json::to_string_pretty(state) {
        let _ = fs::write(path, json);
    }
}

fn find_executable(name: &str) -> Option<PathBuf> {
    if let Ok(path_var) = std::env::var("PATH") {
        for dir in std::env::split_paths(&path_var) {
            let candidate = dir.join(name);
            if candidate.is_file() && is_executable(&candidate) {
                return Some(candidate);
            }
        }
    }
    // Also check standard NixOS / current system paths
    let standard = [
        PathBuf::from("/run/current-system/sw/bin").join(name),
        home_dir().join(".local/bin").join(name),
        home_dir().join("doty/modules/scripts").join(name),
    ];
    standard
        .into_iter()
        .find(|cand| cand.is_file() && is_executable(cand))
}

#[cfg(unix)]
fn is_executable(path: &Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    fs::metadata(path)
        .map(|m| m.permissions().mode() & 0o111 != 0)
        .unwrap_or(false)
}

#[cfg(not(unix))]
fn is_executable(path: &Path) -> bool {
    path.is_file()
}

fn scan_candidate_directories() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    let home = home_dir();

    dirs.push(home.join("Downloads"));
    dirs.push(home.join("Models"));
    dirs.push(home.join(".cache/huggingface/hub"));
    dirs.push(PathBuf::from("."));

    if let Ok(custom) = std::env::var("SD_MODELS_DIR") {
        dirs.push(PathBuf::from(custom));
    }

    dirs.retain(|d| d.is_dir());
    dirs
}

fn discover_models() -> Vec<ModelInfo> {
    let search_dirs = scan_candidate_directories();
    let mut found_files = Vec::new();

    for dir in &search_dirs {
        scan_dir_recursive(dir, 0, 3, &mut found_files);
    }

    let mut models = Vec::new();

    // 1. Look for Qwen-Image 2.1
    let qwen_diffusions: Vec<&PathBuf> = found_files
        .iter()
        .filter(|p| {
            let name = p
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("")
                .to_lowercase();
            (name.contains("qwen-image") || (name.contains("qwen") && name.contains("image")))
                && name.ends_with(".gguf")
        })
        .collect();

    let qwen_vaes: Vec<&PathBuf> = found_files
        .iter()
        .filter(|p| {
            let name = p
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("")
                .to_lowercase();
            name.contains("qwen")
                && name.contains("vae")
                && (name.ends_with(".safetensors") || name.ends_with(".gguf"))
        })
        .collect();

    let qwen_llms: Vec<&PathBuf> = found_files
        .iter()
        .filter(|p| {
            let name = p
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("")
                .to_lowercase();
            (name.contains("qwen3vl")
                || name.contains("qwen3_vl")
                || (name.contains("qwen") && name.contains("vl")))
                && (name.ends_with(".safetensors") || name.ends_with(".gguf"))
        })
        .collect();

    for diff in qwen_diffusions {
        let file_stem = diff
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("qwen-image-2.1");
        let vae = qwen_vaes.first().map(|p| (*p).clone());
        let llm = qwen_llms.first().map(|p| (*p).clone());

        models.push(ModelInfo {
            id: file_stem.to_string(),
            name: format!("Qwen-Image 2.1 ({})", file_stem),
            model_type: "qwen-image-2.1".to_string(),
            diffusion_path: diff.clone(),
            vae_path: vae,
            llm_path: llm,
            default_steps: 25,
            default_cfg: 6.0,
            default_sampler: "euler".to_string(),
            default_width: 1024,
            default_height: 1024,
        });
    }

    // 2. Look for other models (.safetensors, .gguf)
    for file in &found_files {
        let name = file
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("")
            .to_lowercase();
        if !name.ends_with(".safetensors") && !name.ends_with(".gguf") && !name.ends_with(".ckpt") {
            continue;
        }

        // Skip files already identified or irrelevant
        if name.contains("qwen")
            || name.contains("mmproj")
            || name.contains("embedding")
            || name.contains("vae")
        {
            continue;
        }

        let is_diffusion = name.contains("sd")
            || name.contains("flux")
            || name.contains("diffusion")
            || name.contains("xl")
            || name.contains("dream");

        if is_diffusion {
            let file_stem = file.file_stem().and_then(|s| s.to_str()).unwrap_or("model");
            let mtype = if name.contains("xl") {
                "sdxl"
            } else if name.contains("flux") {
                "flux"
            } else {
                "generic"
            };

            models.push(ModelInfo {
                id: file_stem.to_string(),
                name: file_stem.to_string(),
                model_type: mtype.to_string(),
                diffusion_path: file.clone(),
                vae_path: None,
                llm_path: None,
                default_steps: if mtype == "flux" { 20 } else { 25 },
                default_cfg: if mtype == "flux" { 3.5 } else { 7.0 },
                default_sampler: "euler".to_string(),
                default_width: if mtype == "sd15" { 512 } else { 1024 },
                default_height: if mtype == "sd15" { 512 } else { 1024 },
            });
        }
    }

    models
}

fn scan_dir_recursive(dir: &Path, depth: usize, max_depth: usize, found: &mut Vec<PathBuf>) {
    if depth > max_depth {
        return;
    }
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file() {
            let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
            if ext == "gguf" || ext == "safetensors" || ext == "ckpt" {
                found.push(path);
            }
        } else if path.is_dir() {
            let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if !name.starts_with('.') && name != "node_modules" && name != "target" {
                scan_dir_recursive(&path, depth + 1, max_depth, found);
            }
        }
    }
}

fn parse_cli_args() -> Result<CliArgs, String> {
    let mut args = CliArgs::default();
    let raw_args: Vec<String> = std::env::args().skip(1).collect();

    if raw_args.is_empty() {
        return Ok(args);
    }

    let mut i = 0;
    while i < raw_args.len() {
        let arg = &raw_args[i];

        if !arg.starts_with('-') && i == 0 {
            args.command = Some(arg.clone());
            i += 1;
            continue;
        }

        match arg.as_str() {
            "-h" | "--help" => {
                print_help();
                std::process::exit(0);
            }
            "-p" | "--prompt" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--prompt requires a value".into());
                }
                args.prompt = Some(raw_args[i].clone());
            }
            "-n" | "--negative-prompt" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--negative-prompt requires a value".into());
                }
                args.negative_prompt = Some(raw_args[i].clone());
            }
            "-m" | "--model" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--model requires a value".into());
                }
                args.model = Some(raw_args[i].clone());
            }
            "--vae" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--vae requires a path".into());
                }
                args.vae = Some(PathBuf::from(&raw_args[i]));
            }
            "--llm" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--llm requires a path".into());
                }
                args.llm = Some(PathBuf::from(&raw_args[i]));
            }
            "-o" | "--output" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--output requires a path".into());
                }
                args.output = Some(PathBuf::from(&raw_args[i]));
            }
            "--steps" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--steps requires an integer".into());
                }
                let val: u32 = raw_args[i].parse().map_err(|_| "Invalid steps number")?;
                args.steps = Some(val);
            }
            "--cfg" | "--cfg-scale" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--cfg requires a float".into());
                }
                let val: f32 = raw_args[i].parse().map_err(|_| "Invalid cfg scale")?;
                args.cfg = Some(val);
            }
            "--sampler" | "--sampling-method" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--sampler requires a name".into());
                }
                args.sampler = Some(raw_args[i].clone());
            }
            "-W" | "--width" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--width requires an integer".into());
                }
                let val: u32 = raw_args[i].parse().map_err(|_| "Invalid width")?;
                args.width = Some(val);
            }
            "-H" | "--height" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--height requires an integer".into());
                }
                let val: u32 = raw_args[i].parse().map_err(|_| "Invalid height")?;
                args.height = Some(val);
            }
            "-s" | "--seed" => {
                i += 1;
                if i >= raw_args.len() {
                    return Err("--seed requires an integer".into());
                }
                let val: i64 = raw_args[i].parse().map_err(|_| "Invalid seed")?;
                args.seed = Some(val);
            }
            "--offload-to-cpu" => {
                args.offload_to_cpu = Some(true);
            }
            "--no-offload" => {
                args.offload_to_cpu = Some(false);
            }
            "--fa" => {
                args.flash_attention = Some(true);
            }
            "--no-fa" => {
                args.flash_attention = Some(false);
            }
            "--json" => {
                args.json = true;
            }
            "--notify" => {
                args.notify = true;
            }
            "-v" | "--verbose" => {
                args.verbose = true;
            }
            _ => {
                // If it's a bare positional argument and we don't have a prompt yet
                if !arg.starts_with('-') && args.prompt.is_none() {
                    args.prompt = Some(arg.clone());
                } else {
                    return Err(format!("Unknown option: {}", arg));
                }
            }
        }
        i += 1;
    }

    Ok(args)
}

fn print_help() {
    println!(
        r#"sd_gen - High performance Stable Diffusion & Qwen-Image 2.1 CLI

USAGE:
    sd_gen [COMMAND] [OPTIONS]
    sd_gen -p "a cinematic photo of a neon cyber city"

COMMANDS:
    generate        Generate an image (default if prompt provided)
    list            List discovered diffusion models, VAEs, and LLM text encoders
    status          Show status of last generation and cached model metrics

OPTIONS:
    -p, --prompt <TEXT>          Prompt for generation (required)
    -n, --negative-prompt <TEXT> Negative prompt
    -m, --model <NAME/PATH>      Model file or name (auto-detected if omitted)
    --vae <PATH>                 VAE path (auto-detected for Qwen-Image)
    --llm <PATH>                 Text encoder/LLM path (auto-detected for Qwen-Image)
    -o, --output <PATH>          Output image path (default: ~/Pictures/sd_gen/gen_<timestamp>.png)
    --steps <INT>                Sampling steps (default: 25 for Qwen, 20 for Flux/SDXL)
    --cfg, --cfg-scale <FLOAT>   CFG scale (default: 6.0 for Qwen, 7.0 for SDXL)
    --sampler <NAME>             Sampling method (euler, euler_a, dpm++2m, etc.)
    -W, --width <INT>            Width in pixels (default: 1024)
    -H, --height <INT>           Height in pixels (default: 1024)
    -s, --seed <INT>             Random seed (-1 for random)
    --offload-to-cpu             Offload layers to CPU (default: true for Qwen-Image)
    --no-offload                 Disable CPU offloading
    --fa                         Enable Flash Attention (default: true)
    --no-fa                      Disable Flash Attention
    --json                       Output machine-readable JSON progress events & results
    --notify                     Send desktop notification on completion
    -v, --verbose                Verbose debug output
    -h, --help                   Print this help message
"#
    );
}

fn emit_event(json_mode: bool, event: &ProgressEvent) {
    if json_mode {
        if let Ok(s) = serde_json::to_string(event) {
            println!("{}", s);
        }
    } else {
        match event {
            ProgressEvent::Start {
                model,
                prompt,
                is_cold_candidate,
            } => {
                let start_type = if *is_cold_candidate {
                    "Cold Start"
                } else {
                    "Warm Start"
                };
                println!(
                    "[sd_gen] Starting image generation with {} [{}]",
                    model, start_type
                );
                println!("   Prompt: \"{}\"", prompt);
            }
            ProgressEvent::Loading { model, elapsed_ms } => {
                print!(
                    "\r[sd_gen] Loading model {}... ({:.1}s)",
                    model,
                    *elapsed_ms as f64 / 1000.0
                );
            }
            ProgressEvent::Loaded {
                model: _,
                load_ms,
                is_cold,
            } => {
                let status = if *is_cold { "Cold Load" } else { "Warm Load" };
                println!(
                    "\n[sd_gen] Model loaded in {:.2}s [{}]",
                    *load_ms as f64 / 1000.0,
                    status
                );
            }
            ProgressEvent::Step {
                step,
                total_steps,
                percent,
                elapsed_ms,
            } => {
                let bar_len = 20;
                let filled = (percent * bar_len as u32 / 100) as usize;
                let bar: String = "█".repeat(filled) + &"░".repeat(bar_len - filled);
                print!(
                    "\r[{}] {}/{} steps ({}%) - {:.1}s",
                    bar,
                    step,
                    total_steps,
                    percent,
                    *elapsed_ms as f64 / 1000.0
                );
            }
            ProgressEvent::Complete {
                output_path,
                total_duration_ms,
                load_duration_ms,
                sample_duration_ms,
                is_cold_start,
                width,
                height,
                steps,
                ..
            } => {
                let start_tag = if *is_cold_start {
                    "Cold Start"
                } else {
                    "Warm Start"
                };
                println!("\nGeneration Complete! [{}]", start_tag);
                println!("   Output: {}", output_path);
                println!("   Resolution: {}x{}, Steps: {}", width, height, steps);
                println!(
                    "   Timings: Total {:.2}s (Load: {:.2}s, Sampling: {:.2}s)",
                    *total_duration_ms as f64 / 1000.0,
                    *load_duration_ms as f64 / 1000.0,
                    *sample_duration_ms as f64 / 1000.0
                );
            }
            ProgressEvent::Error { error } => {
                eprintln!("\nError: {}", error);
            }
        }
    }
}

fn send_desktop_notification(title: &str, body: &str, image_path: Option<&str>) {
    let home = home_dir();
    let osdctl_path = home.join(".config/quickshell/osd/bin/osdctl");
    if osdctl_path.exists() {
        let _ = Command::new(&osdctl_path)
            .args(["show", title, "good", "3000"])
            .status();
    }

    let mut cmd = Command::new("notify-send");
    cmd.args(["-a", "sd_gen", title, body, "-u", "normal"]);
    if let Some(img) = image_path {
        cmd.args(["-i", img]);
    }
    let _ = cmd.status();
}

fn execute_generation(args: CliArgs) -> Result<(), String> {
    let prompt = match args.prompt {
        Some(ref p) if !p.trim().is_empty() => p.trim().to_string(),
        _ => return Err("Missing required prompt. Use -p \"<prompt>\"".into()),
    };

    let discovered = discover_models();

    // Select model
    let selected_model = if let Some(ref m_query) = args.model {
        let m_path = PathBuf::from(m_query);
        if m_path.exists() && m_path.is_file() {
            // Specified an explicit file path
            let stem = m_path
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("custom");
            let is_qwen = m_query.to_lowercase().contains("qwen");
            let vae = args.vae.clone().or_else(|| {
                discovered
                    .iter()
                    .find(|d| d.vae_path.is_some())
                    .and_then(|d| d.vae_path.clone())
            });
            let llm = args.llm.clone().or_else(|| {
                discovered
                    .iter()
                    .find(|d| d.llm_path.is_some())
                    .and_then(|d| d.llm_path.clone())
            });

            ModelInfo {
                id: stem.to_string(),
                name: stem.to_string(),
                model_type: if is_qwen {
                    "qwen-image-2.1".into()
                } else {
                    "generic".into()
                },
                diffusion_path: m_path,
                vae_path: vae,
                llm_path: llm,
                default_steps: if is_qwen { 25 } else { 20 },
                default_cfg: if is_qwen { 6.0 } else { 7.0 },
                default_sampler: "euler".into(),
                default_width: 1024,
                default_height: 1024,
            }
        } else {
            // Find by substring match
            discovered
                .iter()
                .find(|m| {
                    m.id.to_lowercase().contains(&m_query.to_lowercase())
                        || m.name.to_lowercase().contains(&m_query.to_lowercase())
                })
                .cloned()
                .ok_or_else(|| {
                    format!(
                        "Model matching '{}' not found. Run 'sd_gen list' to see available models.",
                        m_query
                    )
                })?
        }
    } else {
        // Auto-select: prefer Qwen-Image 2.1 if available, otherwise first discovered
        discovered
            .iter()
            .find(|m| m.model_type == "qwen-image-2.1")
            .or_else(|| discovered.first())
            .cloned()
            .ok_or_else(|| "No diffusion models found in ~/Models or ~/Downloads. Download a model first or pass --model <PATH>.".to_string())?
    };

    // Find sd-cli executable
    let sd_cli = find_executable("sd-cli")
        .or_else(|| find_executable("sd"))
        .ok_or_else(|| {
            "sd-cli executable not found in PATH or standard system locations.".to_string()
        })?;

    // Determine output path
    let now_ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let output_path = match args.output {
        Some(p) => p,
        None => {
            let pic_dir = home_dir().join("Pictures").join("sd_gen");
            let _ = fs::create_dir_all(&pic_dir);
            pic_dir.join(format!("gen_{}.png", now_ts))
        }
    };

    if let Some(parent) = output_path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    // Determine config values
    let steps = args.steps.unwrap_or(selected_model.default_steps);
    let cfg = args.cfg.unwrap_or(selected_model.default_cfg);
    let sampler = args
        .sampler
        .clone()
        .unwrap_or(selected_model.default_sampler);
    let width = args.width.unwrap_or(selected_model.default_width);
    let height = args.height.unwrap_or(selected_model.default_height);
    let offload = args
        .offload_to_cpu
        .unwrap_or(selected_model.model_type == "qwen-image-2.1");
    let flash_attn = args.flash_attention.unwrap_or(true);
    let seed = args.seed.unwrap_or(-1);

    // Warm vs Cold start tracking
    let last_state = load_last_state();
    let current_model_str = selected_model.diffusion_path.to_string_lossy().to_string();
    let is_cold_candidate = match &last_state {
        Some(st) => {
            let age_secs = now_ts.saturating_sub(st.last_run_timestamp);
            st.last_model_path != current_model_str || age_secs > 600
        }
        None => true,
    };

    emit_event(
        args.json,
        &ProgressEvent::Start {
            model: selected_model.name.clone(),
            prompt: prompt.clone(),
            is_cold_candidate,
        },
    );

    // Construct sd-cli command
    let mut cmd = Command::new(&sd_cli);

    if selected_model.model_type == "qwen-image-2.1" {
        cmd.arg("--diffusion-model")
            .arg(&selected_model.diffusion_path);

        let vae_path = args.vae.as_ref().or(selected_model.vae_path.as_ref());
        if let Some(vae) = vae_path {
            cmd.arg("--vae").arg(vae);
        }

        let llm_path = args.llm.as_ref().or(selected_model.llm_path.as_ref());
        if let Some(llm) = llm_path {
            cmd.arg("--llm").arg(llm);
        }
    } else {
        cmd.arg("-m").arg(&selected_model.diffusion_path);

        if let Some(ref vae) = args.vae {
            cmd.arg("--vae").arg(vae);
        }
    }

    cmd.arg("-p").arg(&prompt);

    if let Some(ref neg) = args.negative_prompt {
        cmd.arg("-n").arg(neg);
    }

    cmd.arg("-o").arg(&output_path);
    cmd.arg("--sampling-method").arg(&sampler);
    cmd.arg("--steps").arg(steps.to_string());
    cmd.arg("--cfg-scale").arg(cfg.to_string());
    cmd.arg("-W").arg(width.to_string());
    cmd.arg("-H").arg(height.to_string());

    if seed >= 0 {
        cmd.arg("-s").arg(seed.to_string());
    }

    if offload {
        cmd.arg("--offload-to-cpu");
    }

    if flash_attn {
        cmd.arg("--fa");
    }

    cmd.arg("-v"); // Verbose output to capture logs and timings

    cmd.stdout(Stdio::piped());
    cmd.stderr(Stdio::piped());

    let t_start = Instant::now();
    let mut child = cmd
        .spawn()
        .map_err(|e| format!("Failed to spawn sd-cli: {}", e))?;

    let stdout = child
        .stdout
        .take()
        .ok_or("Failed to capture sd-cli stdout")?;
    let stderr = child
        .stderr
        .take()
        .ok_or("Failed to capture sd-cli stderr")?;

    // Combine stdout and stderr lines
    let (tx, rx) = std::sync::mpsc::channel::<String>();

    let tx_out = tx.clone();
    std::thread::spawn(move || {
        let reader = BufReader::new(stdout);
        for line in reader.lines().map_while(Result::ok) {
            let _ = tx_out.send(line);
        }
    });

    let tx_err = tx;
    std::thread::spawn(move || {
        let reader = BufReader::new(stderr);
        for line in reader.lines().map_while(Result::ok) {
            let _ = tx_err.send(line);
        }
    });

    let mut model_loaded = false;
    let mut t_loaded: Option<Instant> = None;
    let mut last_step = 0;
    let mut is_cold_final = is_cold_candidate;

    while let Ok(line) = rx.recv() {
        if args.verbose {
            eprintln!("[sd-cli] {}", line);
        }

        let line_lower = line.to_lowercase();

        // Check for model load completion / sampling start
        if !model_loaded
            && (line_lower.contains("generating image:")
                || line_lower.contains("sampling completed")
                || line.contains(&format!("/{} ", steps))
                || (line.contains('|') && line.contains(&format!("/{}", steps))))
        {
            model_loaded = true;
            let loaded_at = Instant::now();
            let load_ms = loaded_at.duration_since(t_start).as_millis() as u64;
            t_loaded = Some(loaded_at);

            // Cold start definition: if load took > 2.5s or previous was cold candidate
            is_cold_final = is_cold_candidate || load_ms > 2500;

            emit_event(
                args.json,
                &ProgressEvent::Loaded {
                    model: selected_model.name.clone(),
                    load_ms,
                    is_cold: is_cold_final,
                },
            );
        }

        // Parse step progress: look for patterns like "12/25" or "48%" or "[12/25]"
        if let Some((cur, total)) = parse_progress_step(&line, steps)
            && cur != last_step
        {
            last_step = cur;
            let percent = (cur * 100 / total.max(1)).min(100);
            let elapsed_ms = t_start.elapsed().as_millis() as u64;

            emit_event(
                args.json,
                &ProgressEvent::Step {
                    step: cur,
                    total_steps: total,
                    percent,
                    elapsed_ms,
                },
            );
        }
    }

    let status = child
        .wait()
        .map_err(|e| format!("Failed to wait for sd-cli: {}", e))?;
    let t_end = Instant::now();
    let total_ms = t_end.duration_since(t_start).as_millis() as u64;

    if !status.success() {
        let err_msg = format!("sd-cli failed with exit status: {}", status);
        emit_event(
            args.json,
            &ProgressEvent::Error {
                error: err_msg.clone(),
            },
        );
        return Err(err_msg);
    }

    let loaded_time = t_loaded.unwrap_or(t_start);
    let load_duration_ms = loaded_time.duration_since(t_start).as_millis() as u64;
    let sample_duration_ms = t_end.duration_since(loaded_time).as_millis() as u64;

    let output_str = output_path.to_string_lossy().to_string();

    let final_event = ProgressEvent::Complete {
        status: "success".into(),
        output_path: output_str.clone(),
        model: selected_model.name.clone(),
        is_cold_start: is_cold_final,
        load_duration_ms,
        sample_duration_ms,
        total_duration_ms: total_ms,
        steps,
        width,
        height,
        cfg,
        prompt: prompt.clone(),
        seed,
    };

    emit_event(args.json, &final_event);

    // Save state
    let new_state = SdGenState {
        last_model: selected_model.name.clone(),
        last_model_path: current_model_str,
        last_run_timestamp: now_ts,
        last_load_ms: load_duration_ms,
        last_sample_ms: sample_duration_ms,
        last_total_ms: total_ms,
        last_output: output_str.clone(),
        is_cold: is_cold_final,
        steps,
        width,
        height,
    };
    save_state(&new_state);

    // Notify if requested
    if args.notify {
        let start_str = if is_cold_final { "Cold" } else { "Warm" };
        let msg = format!(
            "Done in {:.1}s [{}] • {}x{}",
            total_ms as f64 / 1000.0,
            start_str,
            width,
            height
        );
        send_desktop_notification("Image Generated", &msg, Some(&output_str));
    }

    Ok(())
}

fn parse_progress_step(line: &str, expected_total: u32) -> Option<(u32, u32)> {
    // Only parse progress lines from sd-cli sampler, which contain '=' or 'it/s' or 's/it' or '|'
    if !line.contains('|') && !line.contains("it/s") && !line.contains("s/it") {
        return None;
    }

    // Skip tensor loading lines
    if line.contains("tensor") || line.contains("MB/s") || line.contains("GB/s") {
        return None;
    }

    // Pattern 1: " 12/25" or "[12/25]"
    if let Some(slash_idx) = line.find('/') {
        let before = &line[..slash_idx];
        let after = &line[slash_idx + 1..];

        let cur_str: String = before
            .chars()
            .rev()
            .take_while(|c| c.is_ascii_digit())
            .collect();
        let cur_str: String = cur_str.chars().rev().collect();

        let tot_str: String = after.chars().take_while(|c| c.is_ascii_digit()).collect();

        if let (Ok(cur), Ok(tot)) = (cur_str.parse::<u32>(), tot_str.parse::<u32>())
            && tot == expected_total
            && cur <= tot
            && cur > 0
        {
            return Some((cur, tot));
        }
    }

    None
}

fn command_list(json: bool) {
    let models = discover_models();
    if json {
        if let Ok(s) = serde_json::to_string_pretty(&models) {
            println!("{}", s);
        }
    } else {
        println!("Discovered Diffusion Models ({} total):", models.len());
        if models.is_empty() {
            println!("   No models found in ~/Models or ~/Downloads.");
            println!(
                "   Supported: Qwen-Image 2.1 (.gguf + vae + llm safetensors), SDXL, Flux, SD1.5"
            );
            return;
        }
        for (i, m) in models.iter().enumerate() {
            println!("\n[{}] {}", i + 1, m.name);
            println!("    Type:           {}", m.model_type);
            println!("    Diffusion Model: {}", m.diffusion_path.display());
            if let Some(ref vae) = m.vae_path {
                println!("    VAE:             {}", vae.display());
            }
            if let Some(ref llm) = m.llm_path {
                println!("    Text Encoder:    {}", llm.display());
            }
            println!(
                "    Defaults:        {}x{}, {} steps, CFG {}, Sampler: {}",
                m.default_width,
                m.default_height,
                m.default_steps,
                m.default_cfg,
                m.default_sampler
            );
        }
        println!();
    }
}

fn command_status(json: bool) {
    let state = load_last_state();
    if json {
        if let Some(st) = state {
            if let Ok(s) = serde_json::to_string_pretty(&st) {
                println!("{}", s);
            }
        } else {
            println!("{{}}");
        }
    } else {
        match state {
            Some(st) => {
                let now = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .map(|d| d.as_secs())
                    .unwrap_or(0);
                let age_secs = now.saturating_sub(st.last_run_timestamp);
                let age_min = age_secs / 60;
                let start_type = if st.is_cold {
                    "Cold Start"
                } else {
                    "Warm Start"
                };

                println!("sd_gen Status:");
                println!("   Last Model:      {}", st.last_model);
                println!("   Last Output:     {}", st.last_output);
                println!("   Age:             {} minutes ago", age_min);
                println!("   Start Type:      {}", start_type);
                println!(
                    "   Last Timings:    Total {:.2}s (Load: {:.2}s, Sampling: {:.2}s)",
                    st.last_total_ms as f64 / 1000.0,
                    st.last_load_ms as f64 / 1000.0,
                    st.last_sample_ms as f64 / 1000.0
                );
                println!(
                    "   Resolution:      {}x{}, {} steps",
                    st.width, st.height, st.steps
                );
            }
            None => {
                println!("sd_gen Status: No previous runs recorded.");
            }
        }
    }
}

fn main() {
    let args = match parse_cli_args() {
        Ok(a) => a,
        Err(e) => {
            eprintln!("Error: {}", e);
            eprintln!("Run 'sd_gen --help' for usage.");
            std::process::exit(1);
        }
    };

    match args.command.as_deref() {
        Some("list") => command_list(args.json),
        Some("status") => command_status(args.json),
        Some("generate") => {
            if let Err(e) = execute_generation(args) {
                eprintln!("{}", e);
                std::process::exit(1);
            }
        }
        Some(cmd) => {
            eprintln!("Unknown command: {}", cmd);
            eprintln!("Run 'sd_gen --help' for usage.");
            std::process::exit(1);
        }
        None => {
            // Default: if prompt is set, generate; otherwise list or show status
            if args.prompt.is_some() {
                if let Err(e) = execute_generation(args) {
                    eprintln!("{}", e);
                    std::process::exit(1);
                }
            } else {
                command_status(args.json);
            }
        }
    }
}
