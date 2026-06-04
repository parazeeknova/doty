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

    let home = home_dir();
    vec![
        home.join("doty/Pictures/Anime"),
        home.join("Pictures").join("Anime"),
    ]
}

fn is_image(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| {
            matches!(
                ext.to_ascii_lowercase().as_str(),
                "jpg" | "jpeg" | "png" | "gif"
            )
        })
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
    if !is_image(&entry_path) {
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

    if let Some(parent) = thumb.parent() {
        if let Err(err) = fs::create_dir_all(parent) {
            eprintln!(
                "failed to create thumbnail cache {}: {err}",
                parent.display()
            );
            return false;
        }
    }

    let tmp = thumb.with_extension("jpg.tmp");
    let status = Command::new("magick")
        .arg(&wallpaper.path)
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

    let output = Command::new("matugen")
        .arg("image")
        .arg(&wallpaper.path)
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

fn cleanup_stale(cache_dir: &Path, live_thumbs: &BTreeSet<PathBuf>) {
    let Ok(entries) = fs::read_dir(cache_dir) else {
        return;
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|ext| ext.to_str()) != Some("jpg")
            && path.extension().and_then(|ext| ext.to_str()) != Some("json")
        {
            continue;
        }
        // Also keep live JSONs
        let is_stale = if path.extension().and_then(|ext| ext.to_str()) == Some("jpg") {
            !live_thumbs.contains(&path)
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

fn link_anime_wallpapers() {
    let doty_dir = home_dir().join("doty/Pictures/Anime");
    let home_dir_anime = home_dir().join("Pictures").join("Anime");

    if !doty_dir.is_dir() || !home_dir_anime.is_dir() {
        return;
    }

    let Ok(entries) = fs::read_dir(&doty_dir) else {
        return;
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if !is_image(&path) {
            continue;
        }
        let Some(file_name) = path.file_name() else {
            continue;
        };
        let target_link = home_dir_anime.join(file_name);

        let needs_creation = match fs::read_link(&target_link) {
            Ok(_existing_target) => {
                let resolved_existing = fs::canonicalize(&target_link).ok();
                let resolved_src = fs::canonicalize(&path).ok();
                resolved_existing != resolved_src
            }
            Err(_) => !target_link.exists(),
        };

        if needs_creation {
            if target_link.exists() || fs::symlink_metadata(&target_link).is_ok() {
                let _ = fs::remove_file(&target_link);
            }
            if let Err(err) = std::os::unix::fs::symlink(&path, &target_link) {
                eprintln!(
                    "failed to create symlink from {} to {}: {err}",
                    path.display(),
                    target_link.display()
                );
            } else {
                println!("linked {} -> {}", target_link.display(), path.display());
            }
        }
    }
}

fn sync_once(dirs: &[PathBuf], cache_dir: &Path, clean: bool) {
    link_anime_wallpapers();
    let wallpapers = scan_wallpapers(dirs);
    let mut live_thumbs = BTreeSet::new();

    for wallpaper in wallpapers.values() {
        let thumb = thumb_path(cache_dir, &wallpaper.path);
        live_thumbs.insert(thumb.clone());
        generate_thumb(wallpaper, &thumb);
        generate_colors(wallpaper, cache_dir);
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
    link_anime_wallpapers();
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
