use std::env;
use std::io::{BufRead, BufReader};
use std::os::unix::net::UnixStream;
use std::process::Command;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::Duration;

#[derive(Clone, Copy)]
struct Rect {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
}

fn grab_int(text: &str, key: &str) -> Option<i32> {
    let idx = text.find(key)?;
    let rest = text[idx + key.len()..].trim_start();
    let end = rest
        .find(|c: char| !c.is_ascii_digit() && c != '-')
        .unwrap_or(rest.len());
    rest[..end].parse().ok()
}

fn get_rofi_bounds() -> Option<Rect> {
    let out = Command::new("hyprctl")
        .args(["layers", "-j"])
        .output()
        .ok()?;
    let text = String::from_utf8_lossy(&out.stdout);
    let pos = text.find("\"namespace\": \"rofi\"")?;
    let start = pos.saturating_sub(400);
    let end = (pos + 400).min(text.len());
    let window = &text[start..end];
    Some(Rect {
        x: grab_int(window, "\"x\":")?,
        y: grab_int(window, "\"y\":")?,
        w: grab_int(window, "\"w\":")?,
        h: grab_int(window, "\"h\":")?,
    })
}

fn get_cursor_pos() -> Option<(i32, i32)> {
    let out = Command::new("hyprctl").arg("cursorpos").output().ok()?;
    let text = String::from_utf8_lossy(&out.stdout);
    let trimmed = text.trim();
    let mut parts = trimmed.split(',').map(|s| s.trim());
    let x = parts.next()?.parse().ok()?;
    let y = parts.next()?.parse().ok()?;
    Some((x, y))
}

fn inside(b: &Rect, x: i32, y: i32) -> bool {
    x >= b.x && x < b.x + b.w && y >= b.y && y < b.y + b.h
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();

    let mut child = match Command::new("rofi").args(&args).spawn() {
        Ok(c) => c,
        Err(_) => std::process::exit(1),
    };
    let rofi_pid = child.id();

    let done = Arc::new(AtomicBool::new(false));
    let done_event = Arc::clone(&done);
    let done_poll = Arc::clone(&done);
    let rofi_open = Arc::new(AtomicBool::new(false));
    let rofi_open_event = Arc::clone(&rofi_open);

    thread::spawn(move || {
        let sig = match env::var("HYPRLAND_INSTANCE_SIGNATURE") {
            Ok(s) => s,
            Err(_) => return,
        };
        let runtime = env::var("XDG_RUNTIME_DIR").unwrap_or_default();
        if runtime.is_empty() {
            return;
        }
        let sock_path = format!("{}/hypr/{}/.socket2.sock", runtime, sig);
        let stream = match UnixStream::connect(&sock_path) {
            Ok(s) => s,
            Err(_) => return,
        };
        let reader = BufReader::new(stream);
        for line in reader.lines().map_while(Result::ok) {
            if done_event.load(Ordering::Relaxed) {
                break;
            }
            if line.starts_with("openlayer>>rofi") {
                rofi_open_event.store(true, Ordering::Relaxed);
            } else if line.starts_with("closelayer>>rofi") {
                done_event.store(true, Ordering::Relaxed);
                break;
            }
        }
    });

    thread::spawn(move || {
        let mut bounds: Option<Rect> = None;
        let mut consecutive_outside = 0u32;
        let mut last_cursor: Option<(i32, i32)> = None;
        let mut waited_ticks = 0u32;
        let outside_threshold = 6;

        loop {
            if done_poll.load(Ordering::Relaxed) {
                break;
            }
            thread::sleep(Duration::from_millis(80));

            let is_open = rofi_open.load(Ordering::Relaxed);
            if !is_open {
                bounds = None;
                waited_ticks += 1;
                if waited_ticks > 40 {
                    break;
                }
                continue;
            }
            waited_ticks = 0;

            if bounds.is_none() {
                bounds = get_rofi_bounds();
                if bounds.is_none() {
                    continue;
                }
            }
            let b = bounds.unwrap();

            let cur = match get_cursor_pos() {
                Some(p) => p,
                None => continue,
            };

            let moved = match last_cursor {
                Some(prev) => prev != cur,
                None => false,
            };
            last_cursor = Some(cur);

            if inside(&b, cur.0, cur.1) {
                consecutive_outside = 0;
                continue;
            }

            if !moved && consecutive_outside == 0 {
                continue;
            }

            consecutive_outside += 1;
            if consecutive_outside >= outside_threshold {
                let _ = Command::new("kill").arg(rofi_pid.to_string()).status();
                break;
            }
        }
    });

    let _ = child.wait();
    done.store(true, Ordering::Relaxed);
}
