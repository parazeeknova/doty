use serde::Deserialize;
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

    // Treat the cache as stale when it's older than the wallpaper itself — a user may
    // have overwritten the file in place, leaving the path unchanged but the content new.
    let cache_is_fresh = match (fs::metadata(&cache_path), fs::metadata(wallpaper_path)) {
        (Ok(cache_meta), Ok(wall_meta)) => match (cache_meta.modified(), wall_meta.modified()) {
            (Ok(c), Ok(w)) => c >= w,
            _ => false,
        },
        _ => false,
    };

    let json_content = if cache_path.exists() && cache_is_fresh {
        fs::read_to_string(cache_path).ok()?
    } else {
        let is_video = wallpaper_path
            .extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| matches!(ext.to_ascii_lowercase().as_str(), "mp4" | "webm"))
            .unwrap_or(false);

        let matugen_input = if is_video {
            cache_dir.join(format!("{}.jpg", hash))
        } else {
            wallpaper_path.to_path_buf()
        };

        // Run matugen dynamically — either no cache or stale cache.
        let out = Command::new("matugen")
            .arg("image")
            .arg(&matugen_input)
            .arg("--json")
            .arg("hex")
            .arg("--source-color-index")
            .arg("0")
            .output()
            .ok()?;
        if !out.status.success() {
            return None;
        }
        // Refresh the cache so future invocations stay consistent with the wallpaper.
        if let Some(parent) = cache_path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let _ = fs::write(&cache_path, &out.stdout);
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
    load_preset_palette("gruvbox").unwrap_or_else(default_palette)
}

fn default_palette() -> HashMap<String, String> {
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

fn load_preset_palette(name: &str) -> Option<HashMap<String, String>> {
    let path = home_dir()
        .join("doty/wabi/presets")
        .join(format!("{}.toml", name));

    let content = fs::read_to_string(&path).ok()?;
    let value: toml::Value = content.parse().ok()?;
    let colors_table = value.get("colors")?.as_table()?;
    let mut palette = HashMap::new();
    for (key, val) in colors_table {
        if let Some(s) = val.as_str() {
            palette.insert(key.clone(), s.to_string());
        }
    }
    Some(palette)
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

fn get_closest_cmatrix_color(hex: &str) -> String {
    let (r, g, b) = hex_to_rgb_tuple(hex).unwrap_or((0, 255, 0));
    let candidates = vec![
        ("red", (255, 0, 0)),
        ("green", (0, 255, 0)),
        ("yellow", (255, 255, 0)),
        ("blue", (0, 0, 255)),
        ("magenta", (255, 0, 255)),
        ("cyan", (0, 255, 255)),
        ("white", (255, 255, 255)),
        ("black", (0, 0, 0)),
    ];
    let mut best_name = "green".to_string();
    let mut min_dist = f64::MAX;
    for (name, rgb) in candidates {
        let dr = (r as f64) - (rgb.0 as f64);
        let dg = (g as f64) - (rgb.1 as f64);
        let db = (b as f64) - (rgb.2 as f64);
        let dist = dr * dr + dg * dg + db * db;
        if dist < min_dist {
            min_dist = dist;
            best_name = name.to_string();
        }
    }
    best_name
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

    let cmatrix_color = get_closest_cmatrix_color(&accent);
    vars.insert("cmatrix_color".to_string(), cmatrix_color);

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
    vars.insert(
        "bg_dark_rgb_semicolon".to_string(),
        bg_dark_rgb.replace(",", ";"),
    );
    vars.insert(
        "bg_light_rgb_semicolon".to_string(),
        bg_light_rgb.replace(",", ";"),
    );
    vars.insert("fg_rgb_semicolon".to_string(), fg_rgb.replace(",", ";"));
    vars.insert(
        "fg_light_rgb_semicolon".to_string(),
        fg_light_rgb.replace(",", ";"),
    );
    vars.insert(
        "accent_rgb_semicolon".to_string(),
        accent_rgb.replace(",", ";"),
    );
    vars.insert(
        "secondary_rgb_semicolon".to_string(),
        secondary_rgb.replace(",", ";"),
    );
    vars.insert(
        "error_rgb_semicolon".to_string(),
        error_rgb.replace(",", ";"),
    );

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
    let _tertiary = &vars["tertiary"];
    let error = &vars["error"];

    // Build replacement list: order matters — replace more specific colors first
    // to avoid partial matches when colors share prefixes.
    let replacements: Vec<(&str, &str)> = vec![
        // === Accent / selection / checkboxes ===
        // Gruvbox green — checkboxes, radio buttons, itemview selection, progress bars
        ("#b8bb26", accent),
        ("#a9b665", accent),
        ("#98971a", accent), // Darker Gruvbox green variant
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
        ("#c3c370", accent),    // Tooltip shadow hint (yellowish-green)
        ("#717e98", secondary), // Muted blue-grey element
        ("#3c4366", bg_light),  // Dark blue-grey
        ("#5c616c", bg_light),  // Adwaita-style grey (used in close icon class)
        ("#31363b", bg_light),  // Breeze-style dark grey (used in border class)
        ("#222", bg),           // Shorthand dark grey (main window background!)
        ("#333", bg_light),     // Shorthand lighter grey
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

    // Handle --toggle-glass
    if args.len() > 1 && args[1] == "--toggle-glass" {
        toggle_glass();
        return;
    }

    let mut mode = String::new();
    let mut value = String::new();

    let cache_theme_path = home_dir()
        .join(".cache")
        .join("quickshell")
        .join("last_theme");

    if args.len() < 2 || args[1] == "restore" {
        if cache_theme_path.exists()
            && let Ok(content) = fs::read_to_string(&cache_theme_path)
        {
            let parts: Vec<&str> = content.trim().splitn(2, ' ').collect();
            if parts.len() == 2 {
                mode = parts[0].to_string();
                value = parts[1].to_string();
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
        "preset" => load_preset_palette(&value).unwrap_or_else(|| {
            eprintln!(
                "Unknown preset '{}': no file at ~/doty/wabi/presets/{}.toml",
                value, value
            );
            std::process::exit(1);
        }),
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

    // Write colors.json and Colors.qml early so QuickShell picks up new colors
    // immediately, before slow operations (papirus-folders, make sync, bat cache).
    let cache_colors_dir = home_dir().join(".cache").join("quickshell");
    let _ = fs::create_dir_all(&cache_colors_dir);
    let colors_json_dest = cache_colors_dir.join("colors.json");
    if let Ok(json_str) = serde_json::to_string(&vars) {
        let _ = fs::write(colors_json_dest, json_str);
    }
    let colors_tmpl = doty.join("modules/features/wm/quickshell/colors.qml.template");
    let colors_dest = cache_colors_dir.join("Colors.qml");
    if colors_tmpl.exists() && render_template(&colors_tmpl, &colors_dest, &vars) {
        println!("Rendered cache Colors.qml (early)");
    }

    if mode == "wallpaper" {
        let path = Path::new(&value);
        let is_video = path
            .extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| matches!(ext.to_ascii_lowercase().as_str(), "mp4" | "webm"))
            .unwrap_or(false);

        let matugen_input = if is_video {
            let hash = stable_hash(path);
            home_dir()
                .join(".cache")
                .join("quickshell")
                .join("wallpaper_switcher")
                .join("thumbs")
                .join(format!("{}.jpg", hash))
        } else {
            path.to_path_buf()
        };

        let _ = Command::new("matugen")
            .arg("image")
            .arg(&matugen_input)
            .arg("--source-color-index")
            .arg("0")
            .spawn();
    }

    // Define all templates and their destinations
    let mappings = vec![
        (
            "modules/features/wm/hyprland/hypr/modules/colors.lua.template",
            "modules/features/wm/hyprland/hypr/modules/colors.lua",
        ),
        (
            "modules/features/wm/waybar/colors.css.template",
            "modules/features/wm/waybar/colors/matugen.css",
        ),
        (
            ".config/rofi/colors.rasi.template",
            ".config/rofi/colors.rasi",
        ),
        (
            "modules/features/shell/kitty/current-theme.conf.template",
            "modules/features/shell/kitty/current-theme.conf",
        ),
        (
            "modules/features/shell/ghostty/theme.template",
            "modules/features/shell/ghostty/themes/theme",
        ),
        (
            "modules/features/shell/yazi/theme.toml.template",
            "modules/features/shell/yazi/theme.toml",
        ),
        (
            "modules/home/programs/git/colors.template",
            "modules/home/programs/git/colors",
        ),
        (
            "modules/features/shell/lazygit/config.yml.template",
            "modules/features/shell/lazygit/config.yml",
        ),
        (
            "modules/features/shell/btop/themes/matugen.theme.template",
            "modules/features/shell/btop/themes/matugen.theme",
        ),
        (
            "modules/features/shell/bat/themes/matugen.tmTheme.template",
            "modules/features/shell/bat/themes/matugen.tmTheme",
        ),
        (
            ".config/fish/conf.d/matugen-colors.fish.template",
            ".config/fish/conf.d/matugen-colors.fish",
        ),
        (
            ".config/fish/conf.d/fzf-colors.fish.template",
            ".config/fish/conf.d/fzf-colors.fish",
        ),
        (
            "modules/features/shell/eza/theme.yml.template",
            "modules/features/shell/eza/theme.yml",
        ),
        (
            "modules/features/shell/opencode/themes/matugen.json.template",
            "modules/features/shell/opencode/themes/matugen.json",
        ),
        (
            "modules/features/wm/quickshell/Theme.qml.template",
            "modules/features/wm/quickshell/Theme.qml",
        ),
        (
            "modules/features/wm/theming/.config/gtk-3.0/colors.css.template",
            "modules/features/wm/theming/.themes/wabi/gtk-3.0/colors.css",
        ),
        (
            "modules/features/wm/theming/.config/gtk-3.0/colors.css.template",
            "modules/features/wm/theming/.themes/wabi/gtk-3.20/colors.css",
        ),
        (
            "modules/features/wm/theming/.config/gtk-3.0/colors.css.template",
            "modules/features/wm/theming/.config/gtk-3.0/colors.css",
        ),
        (
            "modules/features/wm/theming/.config/gtk-4.0/colors.css.template",
            "modules/features/wm/theming/.themes/wabi/gtk-4.0/colors.css",
        ),
        (
            "modules/features/wm/theming/.config/gtk-4.0/colors.css.template",
            "modules/features/wm/theming/.config/gtk-4.0/colors.css",
        ),
        (
            "modules/features/wm/theming/.config/qt5ct/style-colors.conf.template",
            "modules/features/wm/theming/.config/qt5ct/style-colors.conf",
        ),
        (
            "modules/features/wm/theming/.config/qt6ct/style-colors.conf.template",
            "modules/features/wm/theming/.config/qt6ct/style-colors.conf",
        ),
        (
            "modules/features/wm/mako/config.template",
            "modules/features/wm/mako/config",
        ),
        (
            "modules/features/wm/hyprland/hypr/hyprlock.conf.template",
            "modules/features/wm/hyprland/hypr/hyprlock.conf",
        ),
        (
            "modules/features/wm/theming/.config/Kvantum/wabi/wabi.kvconfig.template",
            "modules/features/wm/theming/.config/Kvantum/wabi/wabi.kvconfig",
        ),
        (
            "modules/features/wm/theming/.config/color-schemes/Kvantum.colors.template",
            "modules/features/wm/theming/.config/color-schemes/Kvantum.colors",
        ),
        (
            "modules/features/shell/starship/starship.toml.template",
            "modules/features/shell/starship/starship.toml",
        ),
        (
            "modules/features/shell/tmux/tmux.conf.template",
            "modules/features/shell/tmux/tmux.conf",
        ),
        (
            "modules/features/shell/fastfetch/config.jsonc.template",
            "modules/features/shell/fastfetch/config.jsonc",
        ),
        (
            "modules/features/shell/cava/config.template",
            "modules/features/shell/cava/config",
        ),
        (
            "modules/features/wm/satty/config.toml.template",
            "modules/features/wm/satty/config.toml",
        ),
        (
            "modules/features/shell/nvim/init.lua.template",
            "modules/features/shell/nvim/init.lua",
        ),
        (
            "modules/features/shell/vim/colors/matugen.vim.template",
            "modules/features/shell/vim/colors/matugen.vim",
        ),
        (
            "modules/features/applications/zathura/zathurarc.template",
            "modules/features/applications/zathura/zathurarc",
        ),
        (
            "modules/features/shell/mpv/mpv.conf.template",
            "modules/features/shell/mpv/mpv.conf",
        ),
        (
            "modules/features/applications/spicetify/Themes/wabi/color.ini.template",
            "modules/features/applications/spicetify/Themes/wabi/color.ini",
        ),
        (
            "modules/features/applications/vesktop/settings/quickCss.css.template",
            "modules/features/applications/vesktop/settings/quickCss.css",
        ),
        (
            "modules/features/wm/hyprland-preview-share-picker/style.css.template",
            "modules/features/wm/hyprland-preview-share-picker/style.css",
        ),
    ];

    for (tmpl, dest) in mappings {
        let t_path = doty.join(tmpl);
        let d_path = doty.join(dest);
        if t_path.exists() && render_template(&t_path, &d_path, &vars) {
            println!("Rendered: {}", dest);
        }
    }

    // Patch Kvantum SVG
    let svg_tmpl = doty.join("modules/features/wm/theming/.config/Kvantum/wabi/wabi.svg.template");
    let svg_dest = doty.join("modules/features/wm/theming/.config/Kvantum/wabi/wabi.svg");
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

        let css_tmpl = doty.join("modules/features/applications/zen/userChrome.css.template");
        let css_dest = chrome_dir.join("userChrome.css");
        if css_tmpl.exists() && render_template(&css_tmpl, &css_dest, &vars) {
            println!(
                "Rendered Zen Browser userChrome.css for {:?}",
                zen_profile.file_name().unwrap_or_default()
            );
        }

        let content_css_tmpl =
            doty.join("modules/features/applications/zen/userContent.css.template");
        let content_css_dest = chrome_dir.join("userContent.css");
        if content_css_tmpl.exists() && render_template(&content_css_tmpl, &content_css_dest, &vars)
        {
            println!(
                "Rendered Zen Browser userContent.css for {:?}",
                zen_profile.file_name().unwrap_or_default()
            );
        }

        // Also render to matugen-userstyles.css, which the
        // matugen-bridge.uc.js reads at runtime and injects into
        // every content document via the Matugen JSWindowActor
        // child. This bypasses Firefox/Zen's userContent.css
        // loading (which is gated by
        // toolkit.legacyUserProfileCustomizations.stylesheets and
        // doesn't always work in Zen's Fission mode).
        let userstyles_dest = chrome_dir.join("matugen-userstyles.css");
        if content_css_tmpl.exists() && render_template(&content_css_tmpl, &userstyles_dest, &vars)
        {
            println!(
                "Rendered Zen Browser matugen-userstyles.css for {:?}",
                zen_profile.file_name().unwrap_or_default()
            );
        }

        // Per-site userstyles (e.g. github). The bridge reads each
        // matugen-userstyles-<host>.css file and the actor child
        // injects the matching file's CSS only when the document
        // hostname matches the host. This is needed because
        // @-moz-document rules are ignored in <style> elements
        // injected at runtime (they only work in userContent.css).
        let github_tmpl =
            doty.join("modules/features/applications/zen/userContent.github.template");
        let github_dest = chrome_dir.join("matugen-userstyles-github.css");
        if github_tmpl.exists() && render_template(&github_tmpl, &github_dest, &vars) {
            println!(
                "Rendered Zen Browser matugen-userstyles-github.css for {:?}",
                zen_profile.file_name().unwrap_or_default()
            );
        }

        let js_src = doty.join("modules/features/applications/zen/fx-autoconfig/profile/chrome/JS/matugen-bridge.uc.js");
        let js_dest = chrome_dir.join("JS").join("matugen-bridge.uc.js");
        if js_src.exists() {
            let _ = fs::create_dir_all(chrome_dir.join("JS"));
            if fs::copy(&js_src, &js_dest).is_ok() {
                println!(
                    "Synced matugen-bridge.uc.js for {:?}",
                    zen_profile.file_name().unwrap_or_default()
                );
            }
        }

        let actor_parent_src =
            doty.join("modules/features/applications/zen/fx-autoconfig/profile/chrome/JS/Matugen/MatugenParent.sys.mjs");
        let actor_parent_dest = chrome_dir
            .join("JS")
            .join("Matugen")
            .join("MatugenParent.sys.mjs");
        if actor_parent_src.exists() {
            let _ = fs::create_dir_all(chrome_dir.join("JS").join("Matugen"));
            let _ = fs::copy(&actor_parent_src, &actor_parent_dest);
        }

        let actor_child_src =
            doty.join("modules/features/applications/zen/fx-autoconfig/profile/chrome/JS/Matugen/MatugenChild.sys.mjs");
        let actor_child_dest = chrome_dir
            .join("JS")
            .join("Matugen")
            .join("MatugenChild.sys.mjs");
        if actor_child_src.exists() {
            let _ = fs::create_dir_all(chrome_dir.join("JS").join("Matugen"));
            let _ = fs::copy(&actor_child_src, &actor_child_dest);
        }

        // Remove legacy files from earlier reload-watcher attempts
        let _ = fs::remove_file(chrome_dir.join("JS").join("zen-reload.uc.js"));
        let _ = fs::remove_file(chrome_dir.join("JS").join("zen-reload.uc.js.disabled"));
        let _ = fs::remove_file(chrome_dir.join("JS").join("zen-reload-frame.js"));
        let _ = fs::remove_file(chrome_dir.join("userChrome.js"));

        // Write matugen-vars.json — the bridge polls this file and on
        // mtime change calls Services.prefs.setStringPref for each
        // matugen.theme.* key, which fires pref observers that push
        // the new --matugen-* values into chrome + every content tab.
        let json = serde_json::json!({
            "bg": vars.get("bg").cloned().unwrap_or_else(|| "#1d2021".into()),
            "bg-dark": vars.get("bg_dark").cloned().unwrap_or_else(|| "#282828".into()),
            "bg-light": vars.get("bg_light").cloned().unwrap_or_else(|| "#3c3836".into()),
            "fg": vars.get("fg").cloned().unwrap_or_else(|| "#ebdbb2".into()),
            "fg-light": vars.get("fg_light").cloned().unwrap_or_else(|| "#d5c4a1".into()),
            "accent": vars.get("accent").cloned().unwrap_or_else(|| "#a9b665".into()),
            "secondary": vars.get("secondary").cloned().unwrap_or_else(|| "#7daea3".into()),
            "tertiary": vars.get("tertiary").cloned().unwrap_or_else(|| "#d8a657".into()),
        });
        let json_dest = chrome_dir.join("matugen-vars.json");
        if fs::write(
            &json_dest,
            serde_json::to_string_pretty(&json).unwrap_or_default(),
        )
        .is_ok()
        {
            println!(
                "Wrote matugen-vars.json for {:?}",
                zen_profile.file_name().unwrap_or_default()
            );
        }

        // Sync fx-autoconfig utils (chrome.manifest, boot.sys.mjs, etc.)
        // Remove stale files first so renames in source (e.g. fs.jsm -> fs.sys.mjs) don't linger.
        let utils_src =
            doty.join("modules/features/applications/zen/fx-autoconfig/profile/chrome/utils");
        let utils_dst = chrome_dir.join("utils");
        if utils_src.exists() {
            let _ = fs::create_dir_all(&utils_dst);
            let src_names: std::collections::HashSet<String> = fs::read_dir(&utils_src)
                .map(|d| {
                    d.flatten()
                        .map(|e| e.file_name().to_string_lossy().into_owned())
                        .collect()
                })
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

        let userjs_tmpl = doty.join("modules/features/applications/zen/user.js.template");
        let userjs_dest = zen_profile.join("user.js");
        if userjs_tmpl.exists() && render_template(&userjs_tmpl, &userjs_dest, &vars) {
            println!(
                "Rendered Zen Browser user.js for {:?}",
                zen_profile.file_name().unwrap_or_default()
            );
        }
    }

    // Sync symlinks only (no cargo rebuild or daemon restart — not needed for color changes)
    let _ = Command::new("stow")
        .arg(".")
        .arg("--ignore=.antigravitycli")
        .current_dir(&doty)
        .status();

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
    let _ = Command::new("pkill")
        .args(["-USR2", "-f", "bin/waybar"])
        .status();
    let _ = Command::new("makoctl").arg("reload").status();
    if Command::new("pgrep")
        .arg("-f")
        .arg("bin/thunar")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
    {
        let _ = Command::new("thunar").arg("-q").status();
        let _ = Command::new("uwsm")
            .arg("app")
            .arg("--")
            .arg("thunar")
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn();
    }
    let _ = Command::new("killall").arg("-USR2").arg("cava").status();
    let _ = Command::new("killall").arg("-USR1").arg("kitty").status();

    // Apply Spicetify theme if installed
    let mut applied = false;
    if Command::new("spicetify").args(["apply", "-n"]).status().map(|s| s.success()).unwrap_or(false) {
        applied = true;
    } else {
        let spicetify_path = home_dir().join(".spicetify").join("spicetify");
        if spicetify_path.exists() && Command::new(&spicetify_path).args(["apply", "-n"]).status().map(|s| s.success()).unwrap_or(false) {
            applied = true;
        }
    }

    if applied {
        if Command::new("pgrep")
            .arg("-x")
            .arg("spotify")
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
        {
            let _ = Command::new("pkill").arg("-x").arg("spotify").status();
            std::thread::sleep(std::time::Duration::from_millis(500));
            let _ = Command::new("uwsm")
                .args(["app", "--", "spotify"])
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn();
        }
    }

    // Rebuild bat's theme cache (non-blocking, picks up on next launch)
    let _ = Command::new("bat").arg("cache").arg("--build").spawn();

    // Generate and write custom vtrgb file to ~/.config/vtrgb
    if let Some(accent_hex) = vars.get("accent_hex")
        && let Some((r, g, b)) = hex_to_rgb_tuple(accent_hex)
    {
        let vtrgb_content = format!(
            "0,170,0,170,0,170,0,{},85,255,85,255,85,255,85,{}\n\
                 0,0,170,85,0,0,170,{},85,85,255,255,85,85,255,{}\n\
                 0,0,0,0,170,170,170,{},85,85,85,85,255,255,255,{}\n",
            r, r, g, g, b, b
        );
        let vtrgb_path = home_dir().join(".config").join("vtrgb");
        let _ = fs::write(vtrgb_path, vtrgb_content);
    }

    // Restore glass state after template rendering
    apply_glass_state();

    // Update keyboard backlight color using kbd_aura utility
    if let Some(accent_hex) = vars.get("accent_hex") {
        let kbd_aura_path = doty.join("scripts/kbd_aura");
        let clean_hex = accent_hex.replace("#", "").to_uppercase();

        let status = if kbd_aura_path.exists() {
            Command::new(&kbd_aura_path).arg(&clean_hex).status()
        } else {
            Command::new("asusctl")
                .args(["aura", "effect", "static", "--colour", &clean_hex])
                .status()
        };

        if let Err(e) = status {
            eprintln!("Failed to apply keyboard backlight color: {}", e);
        }
    }

    println!("Theme applied successfully!");
}

fn toggle_hex_alpha_lines(content: &str, key: &str, line_suffix: &str, want_alpha: bool) -> String {
    content
        .lines()
        .map(|line| {
            let trimmed = line.trim_start();
            if !trimmed.starts_with(key) {
                return line.to_string();
            }
            let hash_idx = match line.find('#') {
                Some(i) => i,
                None => return line.to_string(),
            };
            let after_hash = &line[hash_idx + 1..];
            let hex_end = after_hash
                .find(|c: char| !c.is_ascii_hexdigit())
                .unwrap_or(after_hash.len());
            let hex = &after_hash[..hex_end];
            if hex.len() != 6 && hex.len() != 8 {
                return line.to_string();
            }
            let base = &hex[..6];
            let new_hex = if want_alpha {
                format!("{}80", base)
            } else {
                base.to_string()
            };
            let tail = &after_hash[hex_end..];
            let mut rebuilt = format!("{}#{}{}", &line[..hash_idx], new_hex, tail);
            if !line_suffix.is_empty() && !rebuilt.trim_end().ends_with(line_suffix) {
                rebuilt.push_str(line_suffix);
            }
            rebuilt
        })
        .collect::<Vec<_>>()
        .join("\n")
        + if content.ends_with('\n') { "\n" } else { "" }
}

fn toggle_glass() {
    let home = home_dir();
    let state_file = home.join(".cache").join("quickshell").join("glass_state");
    let tmp_state = std::path::PathBuf::from("/tmp/quickshell_glass_state");

    let current = fs::read_to_string(&state_file)
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "true".to_string());

    let new_state = if current == "true" { "false" } else { "true" };

    let _ = fs::write(&state_file, new_state);
    let _ = fs::write(&tmp_state, new_state);

    apply_glass_state();

    let status = if new_state == "true" { "On" } else { "Off" };
    let color = if new_state == "true" { "good" } else { "bad" };
    let osdctl = home
        .join(".config")
        .join("quickshell")
        .join("osd/bin/osdctl");
    let _ = Command::new(&osdctl)
        .args(["show", &format!("Glass: {}", status), color, "1200"])
        .status();
}

fn apply_glass_state() {
    let home = home_dir();
    let state_file = home.join(".cache").join("quickshell").join("glass_state");

    let glass_enabled = fs::read_to_string(&state_file)
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "true".to_string())
        == "true";

    let (opacity, inactive_opacity, blur) = if glass_enabled {
        ("0.85", "0.75", "true")
    } else {
        ("1.0", "1.0", "false")
    };

    let waybar_css = home.join(".config").join("waybar").join("style.css");
    let rofi_colors = home.join(".config").join("rofi").join("colors.rasi");
    let mako_config = home.join(".config").join("mako").join("config");

    if let Ok(content) = fs::read_to_string(&waybar_css) {
        let updated = if glass_enabled {
            content.replace(
                "background-color: @bg0;",
                "background-color: alpha(@bg0, 0.75);",
            )
        } else {
            content.replace(
                "background-color: alpha(@bg0, 0.75);",
                "background-color: @bg0;",
            )
        };
        let _ = fs::write(&waybar_css, updated);
    }

    if let Ok(content) = fs::read_to_string(&rofi_colors) {
        let updated = toggle_hex_alpha_lines(&content, "bg0:", ";", glass_enabled);
        let _ = fs::write(&rofi_colors, updated);
    }

    if let Ok(content) = fs::read_to_string(&mako_config) {
        let updated = toggle_hex_alpha_lines(&content, "background-color=", "", glass_enabled);
        let _ = fs::write(&mako_config, updated);
    }

    let _ = Command::new("makoctl").arg("reload").status();
    let _ = Command::new("pkill")
        .args(["-USR2", "-f", "bin/waybar"])
        .status();

    let hypr_eval = format!(
        "hl.config({{ decoration = {{ active_opacity = {}, inactive_opacity = {}, blur = {{ enabled = {} }} }} }}); if hl.plugin.hyprglass then hl.plugin.hyprglass.config({{ enabled = {} }}) end",
        opacity, inactive_opacity, blur, glass_enabled
    );
    let _ = Command::new("hyprctl").args(["eval", &hypr_eval]).status();

    println!(
        "Glass state restored: {}",
        if glass_enabled { "enabled" } else { "disabled" }
    );
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
            .arg("-t")
            .arg("Papirus-Dark")
            .arg("-C")
            .arg("grey")
            .arg("-u")
            .spawn();
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
        .arg("-t")
        .arg("Papirus-Dark")
        .arg("-C")
        .arg(best_color)
        .arg("-u")
        .spawn();
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
            if path.is_dir()
                && let Some(name) = path.file_name().map(|n| n.to_string_lossy())
                && (name.contains("Default") || name.contains("default"))
            {
                profiles.push(path);
            }
        }
    }
    profiles
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hex_to_rgb_valid_and_invalid() {
        assert_eq!(hex_to_rgb_tuple("#ff0000"), Some((255, 0, 0)));
        assert_eq!(hex_to_rgb_tuple("#00ff00"), Some((0, 255, 0)));
        assert_eq!(hex_to_rgb_tuple("#0000ff"), Some((0, 0, 255)));
        assert_eq!(hex_to_rgb_tuple("#1d2021"), Some((29, 32, 33)));
        assert_eq!(hex_to_rgb_tuple("ff0000"), Some((255, 0, 0)));
        assert_eq!(hex_to_rgb_tuple("#xyz123"), None);
        assert_eq!(hex_to_rgb_tuple("#123"), None);
        assert_eq!(hex_to_rgb_tuple("#1234567"), None);
    }

    #[test]
    fn closest_cmatrix_color_finds_exact() {
        assert_eq!(get_closest_cmatrix_color("#ff0000"), "red");
        assert_eq!(get_closest_cmatrix_color("#00ff00"), "green");
        assert_eq!(get_closest_cmatrix_color("#ffffff"), "white");
        assert_eq!(get_closest_cmatrix_color("#000000"), "black");
    }

    #[test]
    fn closest_cmatrix_color_finds_nearest() {
        // Near-red should resolve to red
        assert_eq!(get_closest_cmatrix_color("#ee1122"), "red");
        // Near-blue resolves to blue
        assert_eq!(get_closest_cmatrix_color("#1122ee"), "blue");
    }

    #[test]
    fn rgb_to_hex_correct() {
        assert_eq!(rgb_to_hex_string(255, 0, 0), "#ff0000");
        assert_eq!(rgb_to_hex_string(0, 255, 0), "#00ff00");
        assert_eq!(rgb_to_hex_string(0, 0, 0), "#000000");
        assert_eq!(rgb_to_hex_string(255, 255, 255), "#ffffff");
    }

    #[test]
    fn render_template_replaces_variables() {
        let dir = tempfile::tempdir().unwrap();
        let tmpl = dir.path().join("test.template");
        let out = dir.path().join("test.out");
        fs::write(&tmpl, "color: {{bg}}; accent: {{accent_hex}};").unwrap();

        let mut vars = HashMap::new();
        vars.insert("bg".to_string(), "#1d2021".to_string());
        vars.insert("accent_hex".to_string(), "d79921".to_string());

        assert!(render_template(&tmpl, &out, &vars));
        let result = fs::read_to_string(&out).unwrap();
        assert_eq!(result, "color: #1d2021; accent: d79921;");
    }

    #[test]
    fn render_template_static_text_unchanged() {
        let dir = tempfile::tempdir().unwrap();
        let tmpl = dir.path().join("static.template");
        let out = dir.path().join("static.out");
        fs::write(&tmpl, "return {\n  enabled = true\n}").unwrap();

        let vars = HashMap::new();
        assert!(render_template(&tmpl, &out, &vars));
        assert_eq!(
            fs::read_to_string(&out).unwrap(),
            "return {\n  enabled = true\n}"
        );
    }

    #[test]
    fn render_template_nonexistent_input() {
        let out = PathBuf::from("/tmp/should-not-exist-switcher-test.out");
        assert!(!render_template(
            Path::new("/tmp/no-such-template-nonexistent"),
            &out,
            &HashMap::new()
        ));
    }

    #[test]
    fn interpolate_color_produces_gradient() {
        // Midpoint of red and blue should be purple-ish
        let mid = interpolate_color("#ff0000", "#0000ff", 0.5);
        assert!(mid.contains("7f") || mid.contains("80"));

        // Factor 0 returns color1
        assert_eq!(interpolate_color("#ff0000", "#0000ff", 0.0), "#ff0000");

        // Factor 1 returns color2
        assert_eq!(interpolate_color("#ff0000", "#00ff00", 1.0), "#00ff00");
    }
}
