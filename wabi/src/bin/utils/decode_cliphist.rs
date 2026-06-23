use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};

fn main() {
    // Run "cliphist list"
    let output = match Command::new("cliphist").arg("list").output() {
        Ok(out) => out,
        Err(e) => {
            eprintln!("Failed to execute cliphist list: {}", e);
            return;
        }
    };

    let stdout_str = String::from_utf8_lossy(&output.stdout);
    // Take first 25 lines
    for line in stdout_str.lines().take(25) {
        if line.contains("[[") && line.contains("binary data") {
            // Get ID up to the first tab
            let id = match line.split('\t').next() {
                Some(id_str) => id_str.trim(),
                None => continue,
            };

            if id.is_empty() {
                continue;
            }

            let file_path_str = format!("/tmp/clip_{}.png", id);
            let path = Path::new(&file_path_str);
            if !path.exists() {
                // Pipe line into "cliphist decode" and redirect stdout to file
                let mut child = match Command::new("cliphist")
                    .arg("decode")
                    .stdin(Stdio::piped())
                    .stdout(Stdio::piped())
                    .spawn()
                {
                    Ok(c) => c,
                    Err(e) => {
                        eprintln!("Failed to spawn cliphist decode: {}", e);
                        continue;
                    }
                };

                if let Some(mut stdin) = child.stdin.take() {
                    let _ = writeln!(stdin, "{}", line);
                }

                if let Ok(out) = child.wait_with_output()
                    && out.status.success()
                {
                    let _ = std::fs::write(path, out.stdout);
                }
            }
        }
    }
}
