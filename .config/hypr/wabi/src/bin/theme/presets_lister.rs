use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use serde::Serialize;

#[derive(Serialize)]
struct PresetEntry {
    name: String,
    path: String,
    colors: BTreeMap<String, String>,
}

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn presets_dir() -> PathBuf {
    if let Ok(value) = env::var("WABI_PRESETS_DIR") {
        return PathBuf::from(value);
    }
    home_dir().join(".config/hypr/wabi/presets")
}

fn parse_preset(path: &Path) -> Option<PresetEntry> {
    let content = fs::read_to_string(path).ok()?;
    let value: toml::Value = content.parse().ok()?;
    let colors_table = value.get("colors")?.as_table()?;
    let mut colors: BTreeMap<String, String> = BTreeMap::new();
    for (key, val) in colors_table {
        if let Some(s) = val.as_str() {
            colors.insert(key.clone(), s.to_string());
        }
    }
    let stem = path.file_stem()?.to_string_lossy().to_string();
    Some(PresetEntry {
        name: stem,
        path: path.to_string_lossy().to_string(),
        colors,
    })
}

fn main() {
    let dir = presets_dir();
    let mut entries: Vec<PresetEntry> = Vec::new();

    if let Ok(read) = fs::read_dir(&dir) {
        for entry in read.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("toml") {
                continue;
            }
            if let Some(preset) = parse_preset(&path) {
                entries.push(preset);
            }
        }
    }

    entries.sort_by(|a, b| a.name.cmp(&b.name));

    match serde_json::to_string(&entries) {
        Ok(json) => println!("{}", json),
        Err(err) => {
            eprintln!("failed to serialize presets: {err}");
            std::process::exit(1);
        }
    }
}
