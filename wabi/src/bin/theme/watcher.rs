use std::collections::{BTreeMap, BTreeSet};
use std::env;
use std::fs;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::{Duration, SystemTime};

const PREVIEW_SIZE: &str = "440x248";
const DEFAULT_INTERVAL_SECS: u64 = 2;

#[derive(Clone, Debug, Eq, PartialEq)]
struct Wallpaper {
    path: PathBuf,
    modified: SystemTime,
}

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn cache_dir() -> PathBuf {
    env::var_os("WALLPAPER_THUMB_CACHE")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            home_dir()
                .join(".cache")
                .join("quickshell")
                .join("wallpaper_switcher")
                .join("thumbs")
        })
}

fn watch_dirs() -> Vec<PathBuf> {
    if let Ok(value) = env::var("WALLPAPER_WATCH_DIRS") {
        return value
            .split(':')
            .filter(|part| !part.trim().is_empty())
            .map(PathBuf::from)
            .collect();
    }

    vec![
        home_dir().join("doty/modules/backgrounds"),
    ]
}

fn is_supported_wallpaper(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| {
            matches!(
                ext.to_ascii_lowercase().as_str(),
                "jpg" | "jpeg" | "png" | "gif" | "mp4" | "webm"
            )
        })
        .unwrap_or(false)
}

fn is_animated(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| matches!(ext.to_ascii_lowercase().as_str(), "gif" | "mp4" | "webm"))
        .unwrap_or(false)
}

fn stable_hash(path: &Path) -> String {
    let mut hasher = DefaultHasher::new();
    path.to_string_lossy().hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

fn thumb_path(cache_dir: &Path, path: &Path) -> PathBuf {
    cache_dir.join(format!("{}.jpg", stable_hash(path)))
}

fn resolve_image(entry_path: PathBuf) -> Option<Wallpaper> {
    if !is_supported_wallpaper(&entry_path) {
        return None;
    }

    let resolved = fs::canonicalize(&entry_path).ok()?;
    let metadata = fs::metadata(&resolved).ok()?;
    if !metadata.is_file() {
        return None;
    }

    Some(Wallpaper {
        path: resolved,
        modified: metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH),
    })
}

fn scan_wallpapers(dirs: &[PathBuf]) -> BTreeMap<PathBuf, Wallpaper> {
    let mut wallpapers = BTreeMap::new();

    for dir in dirs {
        let Ok(entries) = fs::read_dir(dir) else {
            continue;
        };

        for entry in entries.flatten() {
            if let Some(wallpaper) = resolve_image(entry.path()) {
                wallpapers.insert(wallpaper.path.clone(), wallpaper);
            }
        }
    }

    wallpapers
}

fn needs_regen(wallpaper: &Wallpaper, thumb: &Path) -> bool {
    let Ok(metadata) = fs::metadata(thumb) else {
        return true;
    };
    if metadata.len() == 0 {
        return true;
    }
    metadata
        .modified()
        .map(|modified| wallpaper.modified > modified)
        .unwrap_or(true)
}

fn notify_new_image(name: &str) {
    let message = format!("Generated thumbnail for {}", name);
    let _ = Command::new("notify-send")
        .arg("Wallpaper Watcher")
        .arg(message)
        .arg("-i")
        .arg("image-x-generic")
        .status();
}

fn generate_thumb(wallpaper: &Wallpaper, thumb: &Path) -> bool {
    if !needs_regen(wallpaper, thumb) {
        return false;
    }

    if let Some(parent) = thumb.parent()
        && let Err(err) = fs::create_dir_all(parent)
    {
        eprintln!(
            "failed to create thumbnail cache {}: {err}",
            parent.display()
        );
        return false;
    }

    let mut tmp = thumb.to_path_buf();
    tmp.set_extension("tmp.jpg");
    let input_arg = if is_animated(&wallpaper.path) {
        format!("{}[0]", wallpaper.path.display())
    } else {
        wallpaper.path.to_string_lossy().into_owned()
    };

    let status = Command::new("magick")
        .arg(&input_arg)
        .arg("-auto-orient")
        .arg("-thumbnail")
        .arg(format!("{PREVIEW_SIZE}^"))
        .arg("-gravity")
        .arg("center")
        .arg("-extent")
        .arg(PREVIEW_SIZE)
        .arg(&tmp)
        .status();

    let Ok(status) = status else {
        eprintln!("magick is not available; cannot generate thumbnails");
        return false;
    };
    if !status.success() {
        eprintln!(
            "failed to generate thumbnail for {}",
            wallpaper.path.display()
        );
        let _ = fs::remove_file(&tmp);
        return false;
    }

    if let Err(err) = fs::rename(&tmp, thumb) {
        eprintln!(
            "failed to move thumbnail into place {}: {err}",
            thumb.display()
        );
        let _ = fs::remove_file(&tmp);
        return false;
    }

    println!("thumb {}", wallpaper.path.display());
    if let Some(file_name) = wallpaper.path.file_name().and_then(|n| n.to_str()) {
        notify_new_image(file_name);
    }
    true
}

fn generate_colors(wallpaper: &Wallpaper, cache_dir: &Path) {
    let hash = stable_hash(&wallpaper.path);
    let color_cache = cache_dir.join(format!("{}.json", hash));

    if color_cache.exists() {
        return;
    }

    let is_video = wallpaper
        .path
        .extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| matches!(ext.to_ascii_lowercase().as_str(), "mp4" | "webm"))
        .unwrap_or(false);

    let matugen_input = if is_video {
        thumb_path(cache_dir, &wallpaper.path)
    } else {
        wallpaper.path.clone()
    };

    let output = Command::new("matugen")
        .arg("image")
        .arg(&matugen_input)
        .arg("--json")
        .arg("hex")
        .arg("--source-color-index")
        .arg("0")
        .output();

    match output {
        Ok(out) => {
            if out.status.success() {
                if let Err(err) = fs::write(&color_cache, &out.stdout) {
                    eprintln!(
                        "failed to write cached colors to {}: {err}",
                        color_cache.display()
                    );
                } else {
                    println!("colors {}", wallpaper.path.display());
                }
            } else {
                eprintln!(
                    "matugen failed to extract colors for {}: {}",
                    wallpaper.path.display(),
                    String::from_utf8_lossy(&out.stderr)
                );
            }
        }
        Err(err) => {
            eprintln!("matugen is not installed or failed to run: {err}");
        }
    }
}

fn generate_video_preview(wallpaper: &Wallpaper, cache_dir: &Path) -> bool {
    let hash = stable_hash(&wallpaper.path);
    let preview_mp4 = cache_dir.join(format!("{}.mp4", hash));

    let needs_preview_regen = match fs::metadata(&preview_mp4) {
        Ok(meta) => {
            if meta.len() == 0 {
                true
            } else {
                meta.modified()
                    .map(|modified| wallpaper.modified > modified)
                    .unwrap_or(true)
            }
        }
        Err(_) => true,
    };

    if !needs_preview_regen {
        return false;
    }

    let tmp = preview_mp4.with_extension("tmp.mp4");
    let status = Command::new("ffmpeg")
        .arg("-y")
        .arg("-i")
        .arg(&wallpaper.path)
        .arg("-vf")
        .arg("scale=440:248:force_original_aspect_ratio=increase,crop=440:248")
        .arg("-an")
        .arg("-c:v")
        .arg("libx264")
        .arg("-pix_fmt")
        .arg("yuv420p")
        .arg("-preset")
        .arg("fast")
        .arg("-crf")
        .arg("28")
        .arg(&tmp)
        .status();

    let Ok(status) = status else {
        eprintln!("ffmpeg is not available; cannot generate video previews");
        return false;
    };
    if !status.success() {
        eprintln!(
            "failed to generate video preview for {}",
            wallpaper.path.display()
        );
        let _ = fs::remove_file(&tmp);
        return false;
    }

    if let Err(err) = fs::rename(&tmp, &preview_mp4) {
        eprintln!(
            "failed to move preview video into place {}: {err}",
            preview_mp4.display()
        );
        let _ = fs::remove_file(&tmp);
        return false;
    }
    true
}

fn cleanup_stale(cache_dir: &Path, live_thumbs: &BTreeSet<PathBuf>) {
    let Ok(entries) = fs::read_dir(cache_dir) else {
        return;
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|ext| ext.to_str()) != Some("jpg")
            && path.extension().and_then(|ext| ext.to_str()) != Some("json")
            && path.extension().and_then(|ext| ext.to_str()) != Some("mp4")
        {
            continue;
        }
        // Also keep live JSONs and MP4s
        let is_stale = if path.extension().and_then(|ext| ext.to_str()) == Some("jpg") {
            !live_thumbs.contains(&path)
        } else if path.extension().and_then(|ext| ext.to_str()) == Some("mp4") {
            let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
            let corresponding_jpg = cache_dir.join(format!("{}.jpg", stem));
            !live_thumbs.contains(&corresponding_jpg)
        } else {
            // It's a json color cache. Reconstruct corresponding jpg path to check if live
            let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
            let corresponding_jpg = cache_dir.join(format!("{}.jpg", stem));
            !live_thumbs.contains(&corresponding_jpg)
        };

        if is_stale {
            let _ = fs::remove_file(path);
        }
    }
}



fn auto_optimize_video(path: &Path) {
    let Some(ext) = path.extension().and_then(|e| e.to_str()) else {
        return;
    };
    let ext_lower = ext.to_ascii_lowercase();
    if ext_lower != "mp4" && ext_lower != "webm" {
        return;
    }

    if path.to_string_lossy().contains(".tmp_opt.") {
        return;
    }

    let output = Command::new("ffprobe")
        .args([
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height,r_frame_rate",
            "-of",
            "csv=p=0",
            &path.to_string_lossy(),
        ])
        .output();

    let Ok(out) = output else {
        return;
    };

    if !out.status.success() {
        return;
    }

    let info_str = String::from_utf8_lossy(&out.stdout);
    let parts: Vec<&str> = info_str.trim().split(',').collect();
    if parts.len() < 3 {
        return;
    }

    let width: u32 = parts[0].trim().parse().unwrap_or(0);
    let height: u32 = parts[1].trim().parse().unwrap_or(0);

    let fps_parts: Vec<&str> = parts[2].trim().split('/').collect();
    let fps: f64 = if fps_parts.len() == 2 {
        let num: f64 = fps_parts[0].trim().parse().unwrap_or(0.0);
        let den: f64 = fps_parts[1].trim().parse().unwrap_or(1.0);
        if den > 0.0 { num / den } else { 0.0 }
    } else {
        parts[2].trim().parse().unwrap_or(0.0)
    };

    if width > 1920 || height > 1080 || fps > 30.1 {
        let file_name = path.file_name().and_then(|n| n.to_str()).unwrap_or("video");
        let message = format!(
            "Optimizing {} ({}x{} @ {:.1}fps -> 1080p @ 30fps)...",
            file_name, width, height, fps
        );
        println!("{}", message);
        let _ = Command::new("notify-send")
            .arg("Wallpaper Watcher")
            .arg(message)
            .arg("-i")
            .arg("video-x-generic")
            .status();

        let tmp_output = path.with_extension(format!("tmp_opt.{}", ext_lower));

        let ffmpeg_status = Command::new("ffmpeg")
            .arg("-y")
            .arg("-i")
            .arg(path)
            .arg("-vf")
            .arg("scale=1920:1080,fps=30")
            .arg("-c:v")
            .arg("libx264")
            .arg("-crf")
            .arg("22")
            .arg("-preset")
            .arg("fast")
            .arg("-an")
            .arg(&tmp_output)
            .status();

        match ffmpeg_status {
            Ok(status) if status.success() => {
                if let Err(e) = fs::rename(&tmp_output, path) {
                    eprintln!(
                        "Failed to replace original video file with optimized one: {}",
                        e
                    );
                    let _ = fs::remove_file(&tmp_output);
                } else {
                    let success_msg = format!("Successfully optimized {}", file_name);
                    println!("{}", success_msg);
                    let _ = Command::new("notify-send")
                        .arg("Wallpaper Watcher")
                        .arg(success_msg)
                        .arg("-i")
                        .arg("video-x-generic")
                        .status();

                    // Reload the wallpaper if it is the currently active wallpaper
                    let last_wall_path = home_dir().join(".cache").join("last_wallpaper");
                    if let Ok(active_wall) = fs::read_to_string(&last_wall_path) {
                        let active_wall_trimmed = active_wall.trim();
                        if Path::new(active_wall_trimmed) == path {
                            println!("Reloading active optimized wallpaper...");
                            let _ = Command::new("sh")
                                .arg("-c")
                                .arg(format!("$HOME/.config/quickshell/wallpaper_switcher/set_wallpaper '{}'", path.display()))
                                .status();
                        }
                    }
                }
            }
            _ => {
                eprintln!("ffmpeg optimization failed for {}", path.display());
                let _ = fs::remove_file(&tmp_output);
            }
        }
    }
}

fn sync_once(dirs: &[PathBuf], cache_dir: &Path, clean: bool) {
    let wallpapers = scan_wallpapers(dirs);
    let mut live_thumbs = BTreeSet::new();

    for wallpaper in wallpapers.values() {
        auto_optimize_video(&wallpaper.path);

        let thumb = thumb_path(cache_dir, &wallpaper.path);
        live_thumbs.insert(thumb.clone());
        generate_thumb(wallpaper, &thumb);
        generate_colors(wallpaper, cache_dir);

        let is_video = wallpaper
            .path
            .extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| matches!(ext.to_ascii_lowercase().as_str(), "mp4" | "webm"))
            .unwrap_or(false);
        if is_video {
            generate_video_preview(wallpaper, cache_dir);
        }
    }

    if clean {
        cleanup_stale(cache_dir, &live_thumbs);
    }
}

fn interval() -> Duration {
    let secs = env::var("WALLPAPER_THUMB_INTERVAL")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .filter(|value| *value > 0)
        .unwrap_or(DEFAULT_INTERVAL_SECS);
    Duration::from_secs(secs)
}

fn print_wallpapers(dirs: &[PathBuf], cache_dir: &Path) {
    let wallpapers = scan_wallpapers(dirs);
    for wallpaper in wallpapers.values() {
        let thumb = thumb_path(cache_dir, &wallpaper.path);
        let thumb_display = if thumb.exists() {
            thumb
        } else {
            wallpaper.path.clone()
        };
        println!("{}\t{}", wallpaper.path.display(), thumb_display.display());
    }
}

fn main() {
    let once = env::args().any(|arg| arg == "--once");
    let print_mode = env::args().any(|arg| arg == "--print");
    let clean = !env::args().any(|arg| arg == "--no-clean");
    let dirs = watch_dirs();
    let cache = cache_dir();

    if print_mode {
        print_wallpapers(&dirs, &cache);
        return;
    }

    if once {
        sync_once(&dirs, &cache, clean);
        return;
    }

    loop {
        sync_once(&dirs, &cache, clean);
        thread::sleep(interval());
    }
}
