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

fn hex_to_rgb_tuple(hex: &str) -> Option<(u8, u8, u8)> {
    let h = hex.trim_start_matches('#');
    if h.len() == 6 {
        let r = u8::from_str_radix(&h[0..2], 16).ok()?;
        let g = u8::from_str_radix(&h[2..4], 16).ok()?;
        let b = u8::from_str_radix(&h[4..6], 16).ok()?;
        Some((r, g, b))
    } else {
        None
    }
}

fn rgb_to_hex_string(r: u8, g: u8, b: u8) -> String {
    format!("#{:02x}{:02x}{:02x}", r, g, b)
}

fn interpolate_color(c1: &str, c2: &str, factor: f64) -> String {
    let rgb1 = hex_to_rgb_tuple(c1).unwrap_or((0, 0, 0));
    let rgb2 = hex_to_rgb_tuple(c2).unwrap_or((255, 255, 255));
    let r = ((rgb1.0 as f64) * (1.0 - factor) + (rgb2.0 as f64) * factor).round() as u8;
    let g = ((rgb1.1 as f64) * (1.0 - factor) + (rgb2.1 as f64) * factor).round() as u8;
    let b = ((rgb1.2 as f64) * (1.0 - factor) + (rgb2.2 as f64) * factor).round() as u8;
    rgb_to_hex_string(r, g, b)
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

    let bg_rgb = hex_to_rgb(&bg);
    let bg_dark_rgb = hex_to_rgb(&bg_dark);
    let bg_light_rgb = hex_to_rgb(&bg_light);
    let fg_rgb = hex_to_rgb(&fg);
    let fg_light_rgb = hex_to_rgb(&fg_light);
    let accent_rgb = hex_to_rgb(&accent);
    let secondary_rgb = hex_to_rgb(&secondary);
    let error_rgb = hex_to_rgb(&error);

    vars.insert("bg_rgb".to_string(), bg_rgb.clone());
    vars.insert("bg_dark_rgb".to_string(), bg_dark_rgb.clone());
    vars.insert("bg_light_rgb".to_string(), bg_light_rgb.clone());
    vars.insert("fg_rgb".to_string(), fg_rgb.clone());
    vars.insert("fg_light_rgb".to_string(), fg_light_rgb.clone());
    vars.insert("accent_rgb".to_string(), accent_rgb.clone());
    vars.insert("secondary_rgb".to_string(), secondary_rgb.clone());
    vars.insert("error_rgb".to_string(), error_rgb.clone());

    vars.insert("bg_rgb_semicolon".to_string(), bg_rgb.replace(",", ";"));
    vars.insert("bg_dark_rgb_semicolon".to_string(), bg_dark_rgb.replace(",", ";"));
    vars.insert("bg_light_rgb_semicolon".to_string(), bg_light_rgb.replace(",", ";"));
    vars.insert("fg_rgb_semicolon".to_string(), fg_rgb.replace(",", ";"));
    vars.insert("fg_light_rgb_semicolon".to_string(), fg_light_rgb.replace(",", ";"));
    vars.insert("accent_rgb_semicolon".to_string(), accent_rgb.replace(",", ";"));
    vars.insert("secondary_rgb_semicolon".to_string(), secondary_rgb.replace(",", ";"));
    vars.insert("error_rgb_semicolon".to_string(), error_rgb.replace(",", ";"));

    vars.insert("home".to_string(), home_dir().to_string_lossy().to_string());

    // Interpolate 8 colors from accent to tertiary for cava
    for i in 0..8 {
        let factor = i as f64 / 7.0;
        let color = interpolate_color(&accent, &tertiary, factor);
        vars.insert(format!("cava_color_{}", i + 1), color);
    }

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

    let bg = &vars["bg"];
    let bg_dark = &vars["bg_dark"];
    let bg_light = &vars["bg_light"];
    let fg = &vars["fg"];
    let fg_light = &vars["fg_light"];
    let accent = &vars["accent"];
    let secondary = &vars["secondary"];
    let tertiary = &vars["tertiary"];
    let error = &vars["error"];

    // Build replacement list: order matters — replace more specific colors first
    // to avoid partial matches when colors share prefixes.
    let replacements: Vec<(&str, &str)> = vec![
        // === Accent / selection / checkboxes ===
        // Gruvbox green — checkboxes, radio buttons, itemview selection, progress bars
        ("#b8bb26", accent),
        ("#a9b665", accent),
        ("#98971a", accent),       // Darker Gruvbox green variant
        // Gruvbox aqua dark — checked state backgrounds
        ("#427b58", bg_light),
        // Gruvbox aqua — secondary accent elements
        ("#83a598", secondary),

        // === Focused / hover accent ===
        // Gruvbox yellow — focused close buttons, focused tab indicator, focused accent
        ("#fabd2f", accent),
        ("#fadb2f", accent),
        ("#ffb90c", accent),
        // Gruvbox orange — active/hover accents
        ("#fe8018", accent),
        ("#d65d0e", accent),
        ("#d08770", secondary),

        // === Error / close button pressed ===
        ("#fb4934", error),

        // === Foreground / text / icons ===
        // Gruvbox fg (cream/light) — main text, mdi icons, close/min/max icons
        ("#fbf1c7", fg),
        ("#f8f6da", fg),
        ("#f0e3c4", fg_light),
        // Gruvbox grey — muted text, scrollbar handles, borders
        ("#a89984", fg_light),

        // === Backgrounds (replace most-specific first) ===
        // Gruvbox bg3/bg2 — mid-tone surfaces
        ("#504945", bg_light),
        ("#3c3836", bg_light),
        ("#32302f", bg_light),
        // Gruvbox bg1 — slightly lighter bg
        ("#5c5040", bg_light),

        // Nord polar night — used for focus/hover highlight fills
        ("#4c566a", bg_light),
        ("#555761", bg_light),
        ("#555564", bg_light),

        // Generic dark greys used in gradient stops and generic fills
        ("#6e6e70", bg_light),
        ("#414143", bg_light),
        ("#313131", bg_light),
        ("#323234", bg_light),
        ("#28282a", bg_dark),
        ("#232325", bg_dark),
        ("#22252e", bg_dark),
        ("#1e1e20", bg_dark),
        ("#1c1c1c", bg_dark),
        ("#191919", bg_dark),
        ("#131621", bg_dark),

        // Gruvbox bg0 — main dark background
        ("#282828", bg_dark),
        // Gruvbox bg0_h — darkest background
        ("#1d2021", bg),

        // === Button gradient stops ===
        ("#7a7a7c", bg_light),
        ("#646466", bg_light),
        ("#88888a", bg_light),
        ("#727274", bg_light),
        ("#525254", bg_light),
        ("#48484a", bg_light),
        ("#606062", bg_light),
        ("#565658", bg_light),

        // === Misc themed accents ===
        ("#c3c370", accent),       // Tooltip shadow hint (yellowish-green)
        ("#717e98", secondary),    // Muted blue-grey element
        ("#3c4366", bg_light),     // Dark blue-grey
        ("#5c616c", bg_light),     // Adwaita-style grey (used in close icon class)
        ("#31363b", bg_light),     // Breeze-style dark grey (used in border class)
        ("#222", bg),              // Shorthand dark grey (main window background!)
        ("#333", bg_light),        // Shorthand lighter grey
    ];

    let mut rendered = content;
    for (from, to) in replacements {
        rendered = rendered.replace(from, to);
    }

    // Remove blur filter from menu background to make corners square/sharp
    rendered = rendered.replace("filter:url(#filter2077)", "filter:none");

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

    if mode == "wallpaper" {
        let _ = Command::new("matugen")
            .arg("image")
            .arg(&value)
            .arg("--source-color-index")
            .arg("0")
            .status();
    }

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
            ".themes/wabi/gtk-3.0/colors.css",
        ),
        (
            ".config/gtk-3.0/colors.css.template",
            ".themes/wabi/gtk-3.20/colors.css",
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
            ".config/Kvantum/wabi/wabi.kvconfig.template",
            ".config/Kvantum/wabi/wabi.kvconfig",
        ),
        (
            ".config/color-schemes/Kvantum.colors.template",
            ".local/share/color-schemes/Kvantum.colors",
        ),
        (
            ".config/starship.toml.template",
            ".config/starship.toml",
        ),
        (
            ".config/tmux/tmux.conf.template",
            ".config/tmux/tmux.conf",
        ),
        (
            ".config/fastfetch/config.jsonc.template",
            ".config/fastfetch/config.jsonc",
        ),
        (
            ".config/cava/config.template",
            ".config/cava/config",
        ),
        (
            ".config/satty/config.toml.template",
            ".config/satty/config.toml",
        ),
        (
            ".config/nvim/init.lua.template",
            ".config/nvim/init.lua",
        ),
        (
            ".config/vim/colors/matugen.vim.template",
            ".config/vim/colors/matugen.vim",
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
    let svg_tmpl = doty.join(".config/Kvantum/wabi/wabi.svg.template");
    let svg_dest = doty.join(".config/Kvantum/wabi/wabi.svg");
    if svg_tmpl.exists() {
        patch_kvantum_svg(&svg_tmpl, &svg_dest, &vars);
        println!("Patched: Kvantum SVG");
    }

    // Apply Papirus folder colors
    if let Some(accent) = vars.get("accent") {
        apply_papirus_folders(accent);
    }

    // Render Zen Browser colors
    for zen_profile in find_zen_profiles() {
        let chrome_dir = zen_profile.join("chrome");
        let _ = fs::create_dir_all(&chrome_dir);

        let css_tmpl = doty.join(".config/zen/userChrome.css.template");
        let css_dest = chrome_dir.join("userChrome.css");
        if css_tmpl.exists() {
            if render_template(&css_tmpl, &css_dest, &vars) {
                println!("Rendered Zen Browser userChrome.css for {:?}", zen_profile.file_name().unwrap_or_default());
            }
        }

        let content_css_tmpl = doty.join(".config/zen/userContent.css.template");
        let content_css_dest = chrome_dir.join("userContent.css");
        if content_css_tmpl.exists() {
            if render_template(&content_css_tmpl, &content_css_dest, &vars) {
                println!("Rendered Zen Browser userContent.css for {:?}", zen_profile.file_name().unwrap_or_default());
            }
        }

        let js_src = doty.join(".config/zen/fx-autoconfig/profile/chrome/JS/zen-reload.uc.js");
        let js_dest = chrome_dir.join("JS").join("zen-reload.uc.js");
        if js_src.exists() {
            let _ = fs::create_dir_all(chrome_dir.join("JS"));
            if fs::copy(&js_src, &js_dest).is_ok() {
                println!("Synced Zen Browser zen-reload.uc.js for {:?}", zen_profile.file_name().unwrap_or_default());
            }
        }

        // Sync fx-autoconfig utils (chrome.manifest, boot.sys.mjs, etc.)
        // Remove stale files first so renames in source (e.g. fs.jsm -> fs.sys.mjs) don't linger.
        let utils_src = doty.join(".config/zen/fx-autoconfig/profile/chrome/utils");
        let utils_dst = chrome_dir.join("utils");
        if utils_src.exists() {
            let _ = fs::create_dir_all(&utils_dst);
            let src_names: std::collections::HashSet<String> = fs::read_dir(&utils_src)
                .map(|d| d.flatten().map(|e| e.file_name().to_string_lossy().into_owned()).collect())
                .unwrap_or_default();
            if let Ok(existing) = fs::read_dir(&utils_dst) {
                for e in existing.flatten() {
                    if !src_names.contains(&e.file_name().to_string_lossy().into_owned()) {
                        let _ = fs::remove_file(e.path());
                    }
                }
            }
            for name in &src_names {
                let _ = fs::copy(utils_src.join(name), utils_dst.join(name));
            }
        }

        let userjs_tmpl = doty.join(".config/zen/user.js.template");
        let userjs_dest = zen_profile.join("user.js");
        if userjs_tmpl.exists() {
            if render_template(&userjs_tmpl, &userjs_dest, &vars) {
                println!("Rendered Zen Browser user.js for {:?}", zen_profile.file_name().unwrap_or_default());
            }
        }
    }

    // Sync files
    let _ = Command::new("make").arg("sync").current_dir(&doty).status();

    // Reload services
    let _ = Command::new("gsettings")
        .arg("set")
        .arg("org.gnome.desktop.interface")
        .arg("gtk-theme")
        .arg("wabi")
        .status();
    let _ = Command::new("gsettings")
        .arg("set")
        .arg("org.gnome.desktop.interface")
        .arg("color-scheme")
        .arg("prefer-dark")
        .status();
    let _ = Command::new("hyprctl").arg("reload").status();
    let _ = Command::new("killall").arg("-USR2").arg("waybar").status();
    let _ = Command::new("makoctl").arg("reload").status();
    let _ = Command::new("thunar").arg("-q").status();
    let _ = Command::new("killall").arg("-USR2").arg("cava").status();
    let _ = Command::new("killall").arg("-USR1").arg("kitty").status();

    // Write colors.json to cache folder for dynamic color switching in QuickShell
    let colors_json_dest = cache_colors_dir.join("colors.json");
    if let Ok(json_str) = serde_json::to_string(&vars) {
        let _ = fs::write(colors_json_dest, json_str);
    }

    println!("Theme applied successfully!");
}

fn rgb_to_hsl(r: f64, g: f64, b: f64) -> (f64, f64, f64) {
    let r = r / 255.0;
    let g = g / 255.0;
    let b = b / 255.0;
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let l = (max + min) / 2.0;
    if (max - min).abs() < 1e-6 {
        return (0.0, 0.0, l);
    }
    let d = max - min;
    let s = if l > 0.5 {
        d / (2.0 - max - min)
    } else {
        d / (max + min)
    };
    let h = if (max - r).abs() < 1e-6 {
        let mut h = (g - b) / d;
        if g < b {
            h += 6.0;
        }
        h
    } else if (max - g).abs() < 1e-6 {
        (b - r) / d + 2.0
    } else {
        (r - g) / d + 4.0
    };
    (h * 60.0, s, l)
}

fn apply_papirus_folders(accent_hex: &str) {
    let accent = accent_hex.trim_start_matches('#');
    let (r, g, b) = if accent.len() == 6 {
        let r = u8::from_str_radix(&accent[0..2], 16).unwrap_or(0) as f64;
        let g = u8::from_str_radix(&accent[2..4], 16).unwrap_or(0) as f64;
        let b = u8::from_str_radix(&accent[4..6], 16).unwrap_or(0) as f64;
        (r, g, b)
    } else {
        return;
    };

    let (accent_h, accent_s, _accent_l) = rgb_to_hsl(r, g, b);

    // Papirus color palette with representative RGB values
    let colors: Vec<(&str, (f64, f64, f64))> = vec![
        ("black", (66.0, 66.0, 66.0)),
        ("blue", (75.0, 127.0, 212.0)),
        ("bluegrey", (96.0, 125.0, 139.0)),
        ("brown", (141.0, 110.0, 99.0)),
        ("carmine", (163.0, 0.0, 0.0)),
        ("cyan", (0.0, 188.0, 212.0)),
        ("darkcyan", (0.0, 139.0, 139.0)),
        ("deeporange", (255.0, 87.0, 34.0)),
        ("green", (135.0, 175.0, 135.0)),
        ("grey", (158.0, 158.0, 158.0)),
        ("indigo", (63.0, 81.0, 181.0)),
        ("magenta", (233.0, 30.0, 99.0)),
        ("nordic", (94.0, 129.0, 172.0)),
        ("orange", (255.0, 152.0, 0.0)),
        ("palebrown", (188.0, 170.0, 164.0)),
        ("paleorange", (255.0, 171.0, 145.0)),
        ("pink", (244.0, 143.0, 177.0)),
        ("red", (239.0, 83.0, 80.0)),
        ("teal", (0.0, 150.0, 136.0)),
        ("violet", (156.0, 39.0, 176.0)),
        ("white", (224.0, 224.0, 224.0)),
        ("yaru", (233.0, 84.0, 32.0)),
        ("yellow", (255.0, 235.0, 59.0)),
    ];

    // If accent is very desaturated, use grey
    if accent_s < 0.15 {
        println!("Setting Papirus folders to: grey (desaturated accent)");
        let _ = Command::new("papirus-folders")
            .arg("-C")
            .arg("grey")
            .status();
        return;
    }

    let mut best_color = "blue";
    let mut best_score = f64::MAX;

    for (name, (cr, cg, cb)) in &colors {
        let (ch, cs, _cl) = rgb_to_hsl(*cr, *cg, *cb);

        // Skip achromatic colors for chromatic accents
        if cs < 0.1 {
            continue;
        }

        // Hue distance on circular 0-360 scale
        let mut hue_diff = (accent_h - ch).abs();
        if hue_diff > 180.0 {
            hue_diff = 360.0 - hue_diff;
        }

        // Weighted score: hue is most important, saturation difference as tiebreaker
        let sat_diff = (accent_s - cs).abs();
        let score = hue_diff * 3.0 + sat_diff * 50.0;

        if score < best_score {
            best_score = score;
            best_color = name;
        }
    }

    println!("Setting Papirus folders to: {}", best_color);
    let _ = Command::new("papirus-folders")
        .arg("-C")
        .arg(best_color)
        .status();
}

fn find_zen_profiles() -> Vec<PathBuf> {
    let mut profiles = Vec::new();
    let zen_dir = home_dir().join(".config").join("zen");
    if !zen_dir.exists() {
        return profiles;
    }
    if let Ok(entries) = fs::read_dir(&zen_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                if let Some(name) = path.file_name().map(|n| n.to_string_lossy()) {
                    if name.contains("Default") || name.contains("default") {
                        profiles.push(path);
                    }
                }
            }
        }
    }
    profiles
}
