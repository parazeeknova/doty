use helpers_rs::{parse_percent, print_json};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::process::Command;

const CURRENT_PLAYER_FILE: &str = "/tmp/quickshell_current_media_player";

fn current_player_path() -> PathBuf {
    PathBuf::from(CURRENT_PLAYER_FILE)
}

fn load_current_player() -> Option<String> {
    fs::read_to_string(current_player_path())
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

#[allow(dead_code)]
fn save_current_player(name: &str) {
    let _ = fs::write(current_player_path(), name);
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct SinkInfo {
    index: serde_json::Value,
    name: String,
    description: String,
    volume: i64,
    muted: bool,
    is_bluetooth: bool,
    sample_rate: String,
    icon: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct SourceInfo {
    index: serde_json::Value,
    name: String,
    description: String,
    volume: i64,
    muted: bool,
    icon: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct AppInfo {
    index: serde_json::Value,
    name: String,
    volume: i64,
    muted: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct Diagnostics {
    pipewire_version: String,
    sample_rate: String,
    output_desc: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct MediaInfo {
    player: String,
    title: String,
    artist: String,
    art_url: String,
    status: String,
    position: f64,
    length: f64,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct MediaSource {
    name: String,
    status: String,
    title: String,
    artist: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct AudioResult {
    default_sink: Option<SinkInfo>,
    default_source: Option<SourceInfo>,
    sinks: Vec<SinkInfo>,
    sources: Vec<SourceInfo>,
    apps: Vec<AppInfo>,
    diagnostics: Diagnostics,
    media: Option<MediaInfo>,
    media_sources: Vec<MediaSource>,
    current_media_source: Option<String>,
}

fn get_pactl_json(category: &str) -> serde_json::Value {
    let Ok(output) = Command::new("pactl")
        .args(["-f", "json", "list", category])
        .output()
    else {
        return serde_json::Value::Array(Vec::new());
    };

    if !output.status.success() {
        return serde_json::Value::Array(Vec::new());
    }

    let out_str = String::from_utf8_lossy(&output.stdout);
    if let Ok(val) = serde_json::from_str::<serde_json::Value>(&out_str) {
        if val.is_array() {
            return val;
        } else if val.is_object() {
            return serde_json::Value::Array(vec![val]);
        }
    }
    serde_json::Value::Array(Vec::new())
}

fn parse_volume(vol_obj: &serde_json::Value) -> i64 {
    if let Some(obj) = vol_obj.as_object() {
        for (_chan, val_dict) in obj {
            if let Some(val_str) = val_dict.get("value_percent").and_then(|v| v.as_str())
                && let Some(vol) = parse_percent(val_str)
            {
                return vol;
            }
        }
    }
    0
}

fn main() {
    let mut default_sink_name = String::new();
    let mut default_source_name = String::new();
    let mut pipewire_version = "Running".to_string();

    if let Ok(output) = Command::new("pactl").arg("info").output()
        && output.status.success()
    {
        let out_str = String::from_utf8_lossy(&output.stdout);
        for line in out_str.lines() {
            if let Some(suffix) = line.strip_prefix("Default Sink:") {
                default_sink_name = suffix.trim().to_string();
            } else if let Some(suffix) = line.strip_prefix("Default Source:") {
                default_source_name = suffix.trim().to_string();
            } else if let Some(suffix) = line.strip_prefix("Server Name:") {
                let server_name = suffix.trim();
                if let Some(ver) = server_name.find('(').and_then(|start| {
                    server_name.find(')').and_then(|end| {
                        if end > start {
                            Some(server_name[start + 1..end].to_string())
                        } else {
                            None
                        }
                    })
                }) {
                    pipewire_version = ver;
                }
            }
        }
    }

    // Process Sinks
    let sinks_raw = get_pactl_json("sinks");
    let mut sinks = Vec::new();
    let mut default_sink = None;

    if let Some(sinks_arr) = sinks_raw.as_array() {
        for s in sinks_arr {
            let vol = parse_volume(s.get("volume").unwrap_or(&serde_json::Value::Null));
            let props = s.get("properties").and_then(|p| p.as_object());
            let device_bus = props
                .and_then(|p| p.get("device.bus"))
                .and_then(|v| v.as_str())
                .unwrap_or("");
            let is_bt = device_bus == "bluetooth";

            let sample_spec = s
                .get("sample_specification")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            let mut sample_rate = "48kHz".to_string();
            if let Some(hz_pos) = sample_spec.find("Hz") {
                let prefix = &sample_spec[..hz_pos];
                let digits: String = prefix
                    .chars()
                    .rev()
                    .take_while(|c| c.is_ascii_digit())
                    .collect();
                let digits: String = digits.chars().rev().collect();
                if let Ok(hz) = digits.parse::<i64>() {
                    sample_rate = format!("{}kHz", hz / 1000);
                }
            }

            let active_port = s
                .get("active_port")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_lowercase();
            let mut icon = "audio-speakers";
            if is_bt {
                icon = "audio-headphones-bluetooth";
            } else if active_port.contains("headphone") {
                icon = "audio-headphones";
            }

            let index = s.get("index").cloned().unwrap_or(serde_json::Value::Null);
            let name = s
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            let description = s
                .get("description")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            let muted = s.get("mute").and_then(|v| v.as_bool()).unwrap_or(false);

            let sink_info = SinkInfo {
                index,
                name: name.clone(),
                description,
                volume: vol,
                muted,
                is_bluetooth: is_bt,
                sample_rate,
                icon: icon.to_string(),
            };

            sinks.push(sink_info.clone());

            if name == default_sink_name {
                default_sink = Some(sink_info);
            }
        }
    }

    // Process Sources
    let sources_raw = get_pactl_json("sources");
    let mut sources = Vec::new();
    let mut default_source = None;

    if let Some(sources_arr) = sources_raw.as_array() {
        for s in sources_arr {
            let name = s.get("name").and_then(|v| v.as_str()).unwrap_or("");
            if s.get("monitor_of_sink").is_some() || name.contains(".monitor") {
                continue;
            }

            let vol = parse_volume(s.get("volume").unwrap_or(&serde_json::Value::Null));
            let index = s.get("index").cloned().unwrap_or(serde_json::Value::Null);
            let description = s
                .get("description")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            let muted = s.get("mute").and_then(|v| v.as_bool()).unwrap_or(false);

            let source_info = SourceInfo {
                index,
                name: name.to_string(),
                description,
                volume: vol,
                muted,
                icon: "audio-input-microphone".to_string(),
            };

            sources.push(source_info.clone());

            if name == default_source_name {
                default_source = Some(source_info);
            }
        }
    }

    // Process Apps
    let apps_raw = get_pactl_json("sink-inputs");
    let mut apps = Vec::new();

    if let Some(apps_arr) = apps_raw.as_array() {
        for a in apps_arr {
            let vol = parse_volume(a.get("volume").unwrap_or(&serde_json::Value::Null));
            let index = a.get("index").cloned().unwrap_or(serde_json::Value::Null);
            let muted = a.get("mute").and_then(|v| v.as_bool()).unwrap_or(false);

            let props = a.get("properties").and_then(|p| p.as_object());
            let app_name = props
                .and_then(|p| p.get("application.name").or_else(|| p.get("media.name")))
                .and_then(|v| v.as_str())
                .unwrap_or("Audio Stream")
                .to_string();

            apps.push(AppInfo {
                index,
                name: app_name,
                volume: vol,
                muted,
            });
        }
    }

    // Fallbacks
    if default_sink.is_none() && !sinks.is_empty() {
        default_sink = Some(sinks[0].clone());
    }
    if default_source.is_none() && !sources.is_empty() {
        default_source = Some(sources[0].clone());
    }

    let diag_sr = default_sink
        .as_ref()
        .map(|s| s.sample_rate.clone())
        .unwrap_or_else(|| "48kHz".to_string());
    let mut diag_desc = default_sink
        .as_ref()
        .map(|s| s.description.clone())
        .unwrap_or_else(|| "Unknown".to_string());
    diag_desc = diag_desc.replace("Analog Stereo", "").trim().to_string();

    let media_sources = get_all_media_sources();
    let current_player = resolve_current_player(&media_sources);
    let media = get_media_info_for(current_player.as_deref());

    let result = AudioResult {
        default_sink,
        default_source,
        sinks,
        sources,
        apps,
        diagnostics: Diagnostics {
            pipewire_version,
            sample_rate: diag_sr,
            output_desc: diag_desc,
        },
        media,
        media_sources,
        current_media_source: current_player,
    };

    print_json(&result);
}

fn get_all_media_sources() -> Vec<MediaSource> {
    let Ok(players_out) = Command::new("playerctl").arg("-l").output() else {
        return Vec::new();
    };
    if !players_out.status.success() {
        return Vec::new();
    }

    let players_str = String::from_utf8_lossy(&players_out.stdout);
    let mut sources: Vec<MediaSource> = Vec::new();

    for line in players_str.lines() {
        let player = line.trim();
        if player.is_empty() {
            continue;
        }
        let status = Command::new("playerctl")
            .args(["--player", player, "status"])
            .output()
            .ok()
            .filter(|o| o.status.success())
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .unwrap_or_else(|| "Stopped".to_string());

        let title = playerctl_metadata(player, "{{title}}").unwrap_or_default();
        let artist = playerctl_metadata(player, "{{artist}}").unwrap_or_default();

        sources.push(MediaSource {
            name: player.to_string(),
            status,
            title,
            artist,
        });
    }

    sources
}

fn resolve_current_player(sources: &[MediaSource]) -> Option<String> {
    if sources.is_empty() {
        return None;
    }

    let stored = load_current_player();

    // Prefer the stored player if it still exists in the source list
    if let Some(ref name) = stored
        && sources.iter().any(|s| &s.name == name)
    {
        return Some(name.clone());
    }

    // Fall back to the first "Playing" player
    if let Some(playing) = sources.iter().find(|s| s.status == "Playing") {
        return Some(playing.name.clone());
    }

    // Then the first "Paused" player
    if let Some(paused) = sources.iter().find(|s| s.status == "Paused") {
        return Some(paused.name.clone());
    }

    // Then just the first one available
    Some(sources[0].name.clone())
}

fn get_media_info_for(player: Option<&str>) -> Option<MediaInfo> {
    let target_player = player?;

    let status_out = Command::new("playerctl")
        .args(["--player", target_player, "status"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|| "Stopped".to_string());

    let player_name = playerctl_metadata(target_player, "{{playerName}}")
        .unwrap_or_else(|| target_player.to_string());
    let title = playerctl_metadata(target_player, "{{title}}").unwrap_or_default();
    let artist = playerctl_metadata(target_player, "{{artist}}").unwrap_or_default();
    let art_url = playerctl_metadata(target_player, "{{mpris:artUrl}}").unwrap_or_default();

    Some(MediaInfo {
        player: player_name,
        title,
        artist,
        art_url,
        status: status_out,
        position: playerctl_position(target_player),
        length: playerctl_length(target_player),
    })
}

fn playerctl_metadata(player: &str, format: &str) -> Option<String> {
    let output = Command::new("playerctl")
        .args(["--player", player, "metadata", "--format", format])
        .output()
        .ok()?;
    output
        .status
        .success()
        .then(|| String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn playerctl_position(player: &str) -> f64 {
    Command::new("playerctl")
        .args(["--player", player, "position"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .and_then(|o| {
            String::from_utf8_lossy(&o.stdout)
                .trim()
                .parse::<f64>()
                .ok()
        })
        .unwrap_or(0.0)
}

fn playerctl_length(player: &str) -> f64 {
    Command::new("playerctl")
        .args([
            "--player",
            player,
            "metadata",
            "--format",
            "{{mpris:length}}",
        ])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .and_then(|o| {
            String::from_utf8_lossy(&o.stdout)
                .trim()
                .parse::<f64>()
                .ok()
        })
        .map(|l| l / 1_000_000.0)
        .unwrap_or(0.0)
}
