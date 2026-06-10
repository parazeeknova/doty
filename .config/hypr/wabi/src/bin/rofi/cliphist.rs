use std::env;
use std::io::{self, Write};
use std::process::{Command, Stdio};

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() > 1 && !args[1].is_empty() {
        if let Ok(rofi_info) = env::var("ROFI_INFO")
            && !rofi_info.is_empty()
        {
            // Decode and copy back to clipboard: cliphist decode "$ROFI_INFO" | wl-copy
            if let Ok(decode_proc) = Command::new("cliphist")
                .args(["decode", &rofi_info])
                .stdout(Stdio::piped())
                .spawn()
                && let Some(stdout) = decode_proc.stdout
            {
                let _ = Command::new("wl-copy").stdin(stdout).status();
            }
        }
        std::process::exit(0);
    }

    // List cliphist entries
    let output = Command::new("cliphist").arg("list").output();

    if let Ok(out) = output
        && out.status.success()
    {
        let stdout_str = String::from_utf8_lossy(&out.stdout);
        for line in stdout_str.lines() {
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 2 {
                let id = parts[0];
                let mut preview = parts[1];
                if preview.starts_with("[[ binary data") {
                    preview = "[image]";
                }
                println!("{}\0info\x1f{}", preview, id);
            }
        }
    }

    println!("\0message\x1fclipboard");
    let _ = io::stdout().flush();
}
