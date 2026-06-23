use std::env;
use std::fs;
use std::process::Command;
use std::thread;
use std::time::Duration;

fn kill_mpvpaper() {
    let _ = Command::new("pkill").args(["-9", "-f", "mpvpaper"]).status();
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: {} <path_to_wallpaper>", args[0]);
        std::process::exit(1);
    }

    let raw_path = &args[1];
    let path = match fs::canonicalize(raw_path) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("Error: Cannot resolve path '{}': {}", raw_path, e);
            std::process::exit(1);
        }
    };

    let path_str = path.to_string_lossy();

    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_lowercase())
        .unwrap_or_default();

    if ext == "mp4" || ext == "webm" {
        // Kill existing mpvpaper instances immediately
        kill_mpvpaper();

        // Spawn mpvpaper with optimal performance flags (30fps limit, bilinear scaling, skipped loop filter)
        let cmd = format!(
            "uwsm app -- mpvpaper -o \"--loop --no-audio --hwdec=no --load-scripts=no --cache=no --demuxer-max-bytes=10M --vd-lavc-fast=yes --vd-lavc-skiploopfilter=all --vf=fps=30 --scale=bilinear --cscale=bilinear --dscale=bilinear --sws-scaler=fast-bilinear --correct-downscaling=no --linear-downscaling=no --sigmoid-upscaling=no --hdr-compute-peak=no\" '*' '{}' >/tmp/mpvpaper_rust.log 2>&1",
            path_str
        );
        println!("Spawning via bash: {}", cmd);
        match Command::new("bash").args(["-c", &cmd]).spawn() {
            Ok(_) => println!("Successfully spawned uwsm app mpvpaper via bash"),
            Err(e) => eprintln!("Error spawning mpvpaper: {}", e),
        }
    } else {
        // Kill mpvpaper
        kill_mpvpaper();

        // Ensure awww-daemon is running
        let awww_running = Command::new("pgrep")
            .args(["-x", "awww-daemon"])
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        if !awww_running {
            let _ = Command::new("uwsm")
                .args(["app", "--", "awww-daemon"])
                .spawn();
            thread::sleep(Duration::from_millis(200));
        }

        // Set wallpaper via awww img
        let _ = Command::new("awww").args(["img", &path_str]).status();
    }
}
