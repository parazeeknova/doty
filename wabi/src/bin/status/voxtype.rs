use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader};
use std::process::{Command, Stdio};

#[derive(Serialize, Deserialize, Debug)]
struct VoxtypeStatus {
    text: String,
    #[serde(rename = "class")]
    status_class: String,
    #[serde(flatten)]
    extra: serde_json::Map<String, serde_json::Value>,
}

fn main() {
    let mut child = Command::new("voxtype")
        .args([
            "status",
            "--follow",
            "--format",
            "json",
            "--icon-theme",
            "nerd-font",
        ])
        .stdout(Stdio::piped())
        .spawn()
        .expect("Failed to execute voxtype status process");

    let stdout = child.stdout.take().expect("Failed to get stdout pipe");
    let reader = BufReader::new(stdout);

    for line in reader.lines().map_while(Result::ok) {
        if let Ok(mut status) = serde_json::from_str::<VoxtypeStatus>(&line) {
            // Customize indicator behavior: show only the mic icon when recording, and empty when not recording/transcribing
            if status.status_class == "recording" {
                status.text = "󰍬".to_string();
            } else if status.status_class != "transcribing" {
                status.text = String::new();
            }
            if let Ok(output_str) = serde_json::to_string(&status) {
                println!("{}", output_str);
            }
        } else {
            // Fallback to printing as-is if parsing fails
            println!("{}", line);
        }
    }

    let _ = child.wait();
}
