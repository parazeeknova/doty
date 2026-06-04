use serde::Serialize;
use serde_json::Value;
use std::process::Command;

#[derive(Serialize)]
struct PodmanResult {
    containers: Value,
    images: Value,
    networks: Value,
}

fn run_podman_json(args: &[&str]) -> Value {
    let output = Command::new("podman").args(args).output();

    if let Ok(out) = output
        && out.status.success()
            && let Ok(val) = serde_json::from_slice(&out.stdout) {
                return val;
            }
    Value::Array(vec![])
}

fn main() {
    let containers = run_podman_json(&["ps", "-a", "--format", "json"]);
    let images = run_podman_json(&["images", "--format", "json"]);
    let networks = run_podman_json(&["network", "ls", "--format", "json"]);

    let result = PodmanResult {
        containers,
        images,
        networks,
    };

    if let Ok(json) = serde_json::to_string(&result) {
        println!("{}", json);
    }
}
