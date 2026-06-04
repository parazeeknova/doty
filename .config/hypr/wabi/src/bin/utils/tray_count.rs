use std::process::Command;

fn main() {
    let out = Command::new("busctl")
        .args([
            "--user",
            "get-property",
            "org.kde.StatusNotifierWatcher",
            "/StatusNotifierWatcher",
            "org.kde.StatusNotifierWatcher",
            "RegisteredStatusNotifierItems",
        ])
        .output();

    let mut count = 0;
    if let Ok(o) = out
        && o.status.success() {
            let stdout_str = String::from_utf8_lossy(&o.stdout);
            let parts: Vec<&str> = stdout_str.split_whitespace().collect();
            if parts.len() >= 2 {
                count = parts[1].parse::<i32>().unwrap_or(0);
            }
        }

    if count <= 0 {
        println!(r#"{{"text": "", "class": "empty"}}"#);
    } else {
        println!(r#"{{"text": "{}", "class": "active"}}"#, count);
    }
}
