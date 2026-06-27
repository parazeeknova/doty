use std::env;
use std::process::Command;

fn hex_to_rgb(hex: &str) -> Option<(u8, u8, u8)> {
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

fn rgb_to_hsl(r: u8, g: u8, b: u8) -> (f64, f64, f64) {
    let r = r as f64 / 255.0;
    let g = g as f64 / 255.0;
    let b = b as f64 / 255.0;
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

fn hsl_to_rgb(h: f64, s: f64, l: f64) -> (u8, u8, u8) {
    let c = (1.0 - (2.0 * l - 1.0).abs()) * s;
    let x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    let m = l - c / 2.0;
    let (r_val, g_val, b_val) = if h < 60.0 {
        (c, x, 0.0)
    } else if h < 120.0 {
        (x, c, 0.0)
    } else if h < 180.0 {
        (0.0, c, x)
    } else if h < 240.0 {
        (0.0, x, c)
    } else if h < 300.0 {
        (x, 0.0, c)
    } else {
        (c, 0.0, x)
    };
    (
        ((r_val + m) * 255.0).round().clamp(0.0, 255.0) as u8,
        ((g_val + m) * 255.0).round().clamp(0.0, 255.0) as u8,
        ((b_val + m) * 255.0).round().clamp(0.0, 255.0) as u8,
    )
}

fn tune_color_for_keyboard(hex: &str) -> String {
    let (r, g, b) = hex_to_rgb(hex).unwrap_or((255, 255, 255));
    let (h, s, l) = rgb_to_hsl(r, g, b);

    // Shift hue slightly for keyboard LEDs (they skew toward cool tones)
    let new_h = (h + 15.0) % 360.0;

    // Saturation: boost to keep colors vivid on LEDs
    let new_s = (s * 1.8).clamp(0.7, 1.0);

    // Lightness: bring down so LEDs show rich color, not white
    let new_l = (l * 0.25).clamp(0.10, 0.24);

    let (nr, ng, nb) = hsl_to_rgb(new_h, new_s, new_l);
    format!("{:02X}{:02X}{:02X}", nr, ng, nb)
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: kbd_aura <HEX_COLOR>");
        std::process::exit(1);
    }

    let raw_color = args[1].trim_start_matches('#');
    let color = tune_color_for_keyboard(raw_color);

    println!(
        "Tuning color from {} to {} for keyboard backlight",
        raw_color, color
    );

    match Command::new("asusctl")
        .args(["aura", "effect", "static", "--colour", &color])
        .status()
    {
        Ok(status) => {
            if status.success() {
                println!("Successfully set keyboard backlight color to: {}", color);
            } else {
                eprintln!("asusctl exited with status: {}", status);
                std::process::exit(1);
            }
        }
        Err(e) => {
            eprintln!("Failed to execute asusctl: {}", e);
            std::process::exit(1);
        }
    }
}
