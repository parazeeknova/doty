use serde::Serialize;
use std::path::Path;
use wabi::{print_json, read_trimmed};

#[derive(Serialize)]
struct SunsetStatus {
    current_state: String,
}

fn main() {
    let home = std::env::var("HOME").unwrap_or_default();
    let state_file = Path::new(&home).join(".config/hypr/sunset.state");
    let current_state = read_trimmed(&state_file).unwrap_or_else(|| "Off".to_string());

    print_json(&SunsetStatus { current_state });
}
