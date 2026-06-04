use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Deserialize)]
struct ColorValue {
    color: String,
}

#[derive(Debug, Deserialize)]
struct ColorMode {
    default: ColorValue,
}

#[derive(Debug, Deserialize)]
struct MatugenColors {
    colors: HashMap<String, ColorMode>,
}

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn stable_hash(path: &Path) -> String {
    let mut hasher = DefaultHasher::new();
    path.to_string_lossy().hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

fn get_matugen_palette(wallpaper_path: &Path) -> Option<HashMap<String, String>> {
    let hash = stable_hash(wallpaper_path);
    let cache_dir = home_dir()
        .join(".cache")
        .join("quickshell")
        .join("wallpaper_switcher")
        .join("thumbs");
    let cache_path = cache_dir.join(format!("{}.json", hash));

    let json_content = if cache_path.exists() {
        fs::read_to_string(cache_path).ok()?
    } else {
        // Run matugen dynamically if cache missed
        let out = Command::new("matugen")
            .arg("image")
            .arg(wallpaper_path)
            .arg("--json")
            .arg("hex")
            .arg("--source-color-index")
            .arg("0")
            .output()
            .ok()?;
        if !out.status.success() {
            return None;
        }
        String::from_utf8_lossy(&out.stdout).to_string()
    };

    let data: MatugenColors = serde_json::from_str(&json_content).ok()?;
    let mut palette = HashMap::new();

    for (name, mode) in data.colors {
        palette.insert(name, mode.default.color);
    }

    Some(palette)
}

fn get_gruvbox_palette() -> HashMap<String, String> {
    let mut p = HashMap::new();
    p.insert("surface".to_string(), "#1d2021".to_string());
    p.insert("surface_container".to_string(), "#282828".to_string());
    p.insert("surface_variant".to_string(), "#3c3836".to_string());
    p.insert("on_surface".to_string(), "#ebdbb2".to_string());
    p.insert("on_surface_variant".to_string(), "#d5c4a1".to_string());
    p.insert("primary".to_string(), "#a9b665".to_string());
    p.insert("primary_container".to_string(), "#b8bb26".to_string());
    p.insert("error".to_string(), "#cc241d".to_string());
    p.insert("secondary".to_string(), "#7daea3".to_string());
    p.insert("tertiary".to_string(), "#d8a657".to_string());
    p
}

fn get_everforest_palette() -> HashMap<String, String> {
    let mut p = HashMap::new();
    p.insert("surface".to_string(), "#2d353b".to_string());
    p.insert("surface_container".to_string(), "#333c43".to_string());
    p.insert("surface_variant".to_string(), "#3d484d".to_string());
    p.insert("on_surface".to_string(), "#d3c6aa".to_string());
    p.insert("on_surface_variant".to_string(), "#e6e2cc".to_string());
    p.insert("primary".to_string(), "#a7c080".to_string());
    p.insert("primary_container".to_string(), "#83c092".to_string());
    p.insert("error".to_string(), "#e67e80".to_string());
    p.insert("secondary".to_string(), "#7fbbb3".to_string());
    p.insert("tertiary".to_string(), "#dbbc7f".to_string());
    p
}

fn build_vars(palette: &HashMap<String, String>) -> HashMap<String, String> {
    let mut vars = HashMap::new();

    let bg = palette
        .get("surface")
        .cloned()
        .unwrap_or_else(|| "#1d2021".to_string());
    let bg_dark = palette
        .get("surface_container")
        .cloned()
        .unwrap_or_else(|| "#282828".to_string());
    let bg_light = palette
        .get("surface_variant")
        .cloned()
        .unwrap_or_else(|| "#3c3836".to_string());
    let fg = palette
        .get("on_surface")
        .cloned()
        .unwrap_or_else(|| "#ebdbb2".to_string());
    let fg_light = palette
        .get("on_surface_variant")
        .cloned()
        .unwrap_or_else(|| "#d5c4a1".to_string());
    let accent = palette
        .get("primary")
        .cloned()
        .unwrap_or_else(|| "#a9b665".to_string());
    let secondary = palette
        .get("secondary")
        .cloned()
        .unwrap_or_else(|| "#7daea3".to_string());
    let tertiary = palette
        .get("tertiary")
        .cloned()
        .unwrap_or_else(|| "#d8a657".to_string());
    let error = palette
        .get("error")
        .cloned()
        .unwrap_or_else(|| "#cc241d".to_string());

    vars.insert("bg".to_string(), bg.clone());
    vars.insert("bg_hex".to_string(), bg.replace("#", ""));
    vars.insert("bg_dark".to_string(), bg_dark.clone());
    vars.insert("bg_dark_hex".to_string(), bg_dark.replace("#", ""));
    vars.insert("bg_light".to_string(), bg_light.clone());
    vars.insert("bg_light_hex".to_string(), bg_light.replace("#", ""));
    vars.insert("fg".to_string(), fg.clone());
    vars.insert("fg_hex".to_string(), fg.replace("#", ""));
    vars.insert("fg_light".to_string(), fg_light.clone());
    vars.insert("fg_light_hex".to_string(), fg_light.replace("#", ""));
    vars.insert("accent".to_string(), accent.clone());
    vars.insert("accent_hex".to_string(), accent.replace("#", ""));
    vars.insert("secondary".to_string(), secondary.clone());
    vars.insert("secondary_hex".to_string(), secondary.replace("#", ""));
    vars.insert("tertiary".to_string(), tertiary.clone());
    vars.insert("tertiary_hex".to_string(), tertiary.replace("#", ""));
    vars.insert("error".to_string(), error.clone());
    vars.insert("error_hex".to_string(), error.replace("#", ""));

    // RGBA helper function
    let hex_to_rgb = |hex: &str| -> String {
        let h = hex.trim_start_matches('#');
        if h.len() == 6 {
            let r = u8::from_str_radix(&h[0..2], 16).unwrap_or(0);
            let g = u8::from_str_radix(&h[2..4], 16).unwrap_or(0);
            let b = u8::from_str_radix(&h[4..6], 16).unwrap_or(0);
            format!("{},{},{}", r, g, b)
        } else {
            "0,0,0".to_string()
        }
    };

    vars.insert("bg_rgb".to_string(), hex_to_rgb(&bg));
    vars.insert("bg_dark_rgb".to_string(), hex_to_rgb(&bg_dark));
    vars.insert("bg_light_rgb".to_string(), hex_to_rgb(&bg_light));
    vars.insert("fg_rgb".to_string(), hex_to_rgb(&fg));
    vars.insert("accent_rgb".to_string(), hex_to_rgb(&accent));
    vars.insert("error_rgb".to_string(), hex_to_rgb(&error));
    vars.insert("home".to_string(), home_dir().to_string_lossy().to_string());

    vars
}

fn render_template(
    template_path: &Path,
    output_path: &Path,
    vars: &HashMap<String, String>,
) -> bool {
    let Ok(content) = fs::read_to_string(template_path) else {
        return false;
    };

    let mut rendered = content;
    for (key, val) in vars {
        let placeholder = format!("{{{{{}}}}}", key);
        rendered = rendered.replace(&placeholder, val);
    }

    if let Some(parent) = output_path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    fs::write(output_path, rendered).is_ok()
}

fn patch_kvantum_svg(svg_template: &Path, svg_output: &Path, vars: &HashMap<String, String>) {
    let Ok(content) = fs::read_to_string(svg_template) else {
        return;
    };

    // Replace standard gruvbox hex colors in Kvantum Gruvbox base theme with themed variables
    let mut rendered = content;
    rendered = rendered.replace("#1d2021", &vars["bg"]);
    rendered = rendered.replace("#282828", &vars["bg_dark"]);
    rendered = rendered.replace("#3c3836", &vars["bg_light"]);
    rendered = rendered.replace("#ebdbb2", &vars["fg"]);
    rendered = rendered.replace("#d5c4a1", &vars["fg_light"]);
    rendered = rendered.replace("#b8bb26", &vars["accent"]);
    rendered = rendered.replace("#a9b665", &vars["accent"]);

    if let Some(parent) = svg_output.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(svg_output, rendered);
}

fn main() {
    let args: Vec<String> = env::args().collect();

    let mut mode = String::new();
    let mut value = String::new();

    let cache_theme_path = home_dir()
        .join(".cache")
        .join("quickshell")
        .join("last_theme");

    if args.len() < 2 || args[1] == "restore" {
        if cache_theme_path.exists() {
            if let Ok(content) = fs::read_to_string(&cache_theme_path) {
                let parts: Vec<&str> = content.trim().splitn(2, ' ').collect();
                if parts.len() == 2 {
                    mode = parts[0].to_string();
                    value = parts[1].to_string();
                }
            }
        }
        if mode.is_empty() {
            mode = "preset".to_string();
            value = "gruvbox".to_string();
        }
    } else {
        mode = args[1].clone();
        if args.len() < 3 {
            eprintln!("Missing argument for mode {}", mode);
            std::process::exit(1);
        }
        value = args[2].clone();
    }

    // Save selection for restore on login
    let _ = fs::create_dir_all(cache_theme_path.parent().unwrap());
    let _ = fs::write(&cache_theme_path, format!("{} {}", mode, value));

    let palette = match mode.as_str() {
        "preset" => match value.as_str() {
            "everforest" => get_everforest_palette(),
            _ => get_gruvbox_palette(),
        },
        "wallpaper" => {
            let wall = Path::new(&value);
            match get_matugen_palette(wall) {
                Some(p) => p,
                None => {
                    eprintln!("Failed to extract colors; falling back to Gruvbox");
                    get_gruvbox_palette()
                }
            }
        }
        _ => {
            eprintln!("Unknown mode: {}", mode);
            std::process::exit(1);
        }
    };

    let vars = build_vars(&palette);
    let doty = home_dir().join("doty");

    // Define all templates and their destinations
    let mappings = vec![
        (
            ".config/hypr/modules/colors.lua.template",
            ".config/hypr/modules/colors.lua",
        ),
        (
            ".config/waybar/colors.css.template",
            ".config/waybar/colors/matugen.css",
        ),
        (
            ".config/rofi/colors.rasi.template",
            ".config/rofi/colors.rasi",
        ),
        (
            ".config/kitty/current-theme.conf.template",
            ".config/kitty/current-theme.conf",
        ),
        (
            ".config/ghostty/theme.template",
            ".config/ghostty/themes/theme",
        ),
        (
            ".config/quickshell/Theme.qml.template",
            ".config/quickshell/Theme.qml",
        ),
        (
            ".config/gtk-3.0/colors.css.template",
            ".config/gtk-3.0/colors.css",
        ),
        (
            ".config/gtk-4.0/colors.css.template",
            ".config/gtk-4.0/colors.css",
        ),
        (
            ".config/qt5ct/style-colors.conf.template",
            ".config/qt5ct/style-colors.conf",
        ),
        (
            ".config/qt6ct/style-colors.conf.template",
            ".config/qt6ct/style-colors.conf",
        ),
        (".config/mako/config.template", ".config/mako/config"),
        (
            ".config/hypr/hyprlock.conf.template",
            ".config/hypr/hyprlock.conf",
        ),
        (
            ".config/Kvantum/Gruvbox/Gruvbox.kvconfig.template",
            ".config/Kvantum/Gruvbox/Gruvbox.kvconfig",
        ),
    ];

    for (tmpl, dest) in mappings {
        let t_path = doty.join(tmpl);
        let d_path = doty.join(dest);
        if t_path.exists() {
            if render_template(&t_path, &d_path, &vars) {
                println!("Rendered: {}", dest);
            }
        }
    }

    // Render Colors.qml to cache folder to prevent QuickShell file watcher reload
    let cache_colors_dir = home_dir().join(".cache").join("quickshell");
    let _ = fs::create_dir_all(&cache_colors_dir);
    let colors_tmpl = doty.join(".config/quickshell/colors.qml.template");
    let colors_dest = cache_colors_dir.join("Colors.qml");
    if colors_tmpl.exists() {
        if render_template(&colors_tmpl, &colors_dest, &vars) {
            println!("Rendered cache Colors.qml");
        }
    }

    // Patch Kvantum SVG
    let svg_tmpl = doty.join(".config/Kvantum/Gruvbox/Gruvbox.svg.template");
    let svg_dest = doty.join(".config/Kvantum/Gruvbox/Gruvbox.svg");
    if svg_tmpl.exists() {
        patch_kvantum_svg(&svg_tmpl, &svg_dest, &vars);
        println!("Patched: Kvantum SVG");
    }

    // Apply Papirus folder colors
    if let Some(accent) = vars.get("accent") {
        apply_papirus_folders(accent);
    }

    // Sync files
    let _ = Command::new("make").arg("sync").current_dir(&doty).status();

    // Reload services
    let _ = Command::new("hyprctl").arg("reload").status();
    let _ = Command::new("killall").arg("-USR2").arg("waybar").status();
    let _ = Command::new("makoctl").arg("reload").status();
    let _ = Command::new("thunar").arg("-q").status();

    println!("Theme applied successfully!");
}

fn apply_papirus_folders(accent_hex: &str) {
    let accent = accent_hex.trim_start_matches('#');
    let (r, g, b) = if accent.len() == 6 {
        let r = u8::from_str_radix(&accent[0..2], 16).unwrap_or(0) as i32;
        let g = u8::from_str_radix(&accent[2..4], 16).unwrap_or(0) as i32;
        let b = u8::from_str_radix(&accent[4..6], 16).unwrap_or(0) as i32;
        (r, g, b)
    } else {
        return;
    };

    let colors = vec![
        ("black", (66, 66, 66)),
        ("blue", (75, 127, 212)),
        ("bluegrey", (96, 125, 139)),
        ("brown", (141, 110, 99)),
        ("carmine", (163, 0, 0)),
        ("cyan", (0, 188, 212)),
        ("darkcyan", (0, 139, 139)),
        ("deeporange", (255, 87, 34)),
        ("green", (135, 175, 135)),
        ("grey", (158, 158, 158)),
        ("indigo", (63, 81, 181)),
        ("magenta", (233, 30, 99)),
        ("nordic", (94, 129, 172)),
        ("orange", (255, 152, 0)),
        ("palebrown", (188, 170, 164)),
        ("paleorange", (255, 171, 145)),
        ("pink", (244, 143, 177)),
        ("red", (239, 83, 80)),
        ("teal", (0, 150, 136)),
        ("violet", (156, 39, 176)),
        ("white", (224, 224, 224)),
        ("yaru", (233, 84, 32)),
        ("yellow", (255, 235, 59)),
    ];

    let mut closest_color = "blue";
    let mut min_dist = i32::MAX;

    for (name, (cr, cg, cb)) in colors {
        let dist = (r - cr).pow(2) + (g - cg).pow(2) + (b - cb).pow(2);
        if dist < min_dist {
            min_dist = dist;
            closest_color = name;
        }
    }

    println!("Setting Papirus folders to: {}", closest_color);
    let _ = Command::new("papirus-folders")
        .arg("-C")
        .arg(closest_color)
        .status();
}
