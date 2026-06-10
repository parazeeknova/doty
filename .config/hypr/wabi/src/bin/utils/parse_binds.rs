use serde::Serialize;
use std::collections::HashMap;
use std::fs::File;
use std::io::{self, BufRead, BufReader};
use std::path::Path;

#[derive(Serialize, Clone, Debug)]
struct Bind {
    keys: String,
    description: String,
    cmd: String,
}

#[derive(Serialize, Clone, Debug)]
struct Category {
    category: String,
    binds: Vec<Bind>,
}

fn strip_lua_comments(line: &str) -> String {
    let mut in_single = false;
    let mut in_double = false;
    let chars: Vec<char> = line.chars().collect();
    let mut k = 0;
    while k < chars.len() {
        let char = chars[k];
        if char == '\'' && (k == 0 || chars[k - 1] != '\\') {
            if !in_double {
                in_single = !in_single;
            }
        } else if char == '"' && (k == 0 || chars[k - 1] != '\\') {
            if !in_single {
                in_double = !in_double;
            }
        } else if char == '-' && k < chars.len() - 1 && chars[k + 1] == '-' {
            if !in_single && !in_double {
                return line[..k].trim().to_string();
            }
        }
        k += 1;
    }
    line.trim().to_string()
}

fn parse_balanced_args(text: &str) -> Option<Vec<String>> {
    let start_idx = text.find("hl.bind(")?;
    let start_idx = start_idx + 8;

    let chars: Vec<char> = text.chars().collect();
    let mut depth = 1;
    let mut i = start_idx;
    let mut inner_str = String::new();

    while i < chars.len() && depth > 0 {
        let char = chars[i];
        if char == '(' {
            depth += 1;
        } else if char == ')' {
            depth -= 1;
            if depth == 0 {
                break;
            }
        }
        inner_str.push(char);
        i += 1;
    }

    let mut args = Vec::new();
    let mut current_arg = String::new();
    let mut in_single_quote = false;
    let mut in_double_quote = false;
    let mut brace_depth = 0;
    let mut paren_depth = 0;
    let mut bracket_depth = 0;

    let inner_chars: Vec<char> = inner_str.chars().collect();
    let mut j = 0;
    while j < inner_chars.len() {
        let char = inner_chars[j];
        if char == '\'' && (j == 0 || inner_chars[j - 1] != '\\') {
            if !in_double_quote {
                in_single_quote = !in_single_quote;
            }
        } else if char == '"' && (j == 0 || inner_chars[j - 1] != '\\') {
            if !in_single_quote {
                in_double_quote = !in_double_quote;
            }
        }

        if !in_single_quote && !in_double_quote {
            match char {
                '{' => brace_depth += 1,
                '}' => brace_depth -= 1,
                '(' => paren_depth += 1,
                ')' => paren_depth -= 1,
                '[' => bracket_depth += 1,
                ']' => bracket_depth -= 1,
                ',' if brace_depth == 0 && paren_depth == 0 && bracket_depth == 0 => {
                    args.push(current_arg.trim().to_string());
                    current_arg.clear();
                    j += 1;
                    continue;
                }
                _ => {}
            }
        }

        current_arg.push(char);
        j += 1;
    }

    if !current_arg.trim().is_empty() {
        args.push(current_arg.trim().to_string());
    }

    Some(args)
}

fn evaluate_lua_expr(expr: &str, variables: &HashMap<String, String>) -> String {
    let expr = strip_lua_comments(expr);
    let mut parts = Vec::new();
    let mut current_part = String::new();
    let mut in_single = false;
    let mut in_double = false;

    let chars: Vec<char> = expr.chars().collect();
    let mut k = 0;
    while k < chars.len() {
        let char = chars[k];
        if char == '\'' && (k == 0 || chars[k - 1] != '\\') {
            if !in_double {
                in_single = !in_single;
            }
        } else if char == '"' && (k == 0 || chars[k - 1] != '\\') {
            if !in_single {
                in_double = !in_double;
            }
        }

        if !in_single && !in_double && k < chars.len() - 1 && chars[k] == '.' && chars[k + 1] == '.'
        {
            parts.push(current_part.trim().to_string());
            current_part.clear();
            k += 2;
            continue;
        }

        current_part.push(char);
        k += 1;
    }

    if !current_part.trim().is_empty() {
        parts.push(current_part.trim().to_string());
    }

    let mut resolved = String::new();
    for part in parts {
        let part_trimmed = part.trim();
        if (part_trimmed.starts_with('"') && part_trimmed.ends_with('"'))
            || (part_trimmed.starts_with('\'') && part_trimmed.ends_with('\''))
        {
            if part_trimmed.len() >= 2 {
                resolved.push_str(&part_trimmed[1..part_trimmed.len() - 1]);
            }
        } else if let Some(val) = variables.get(part_trimmed) {
            resolved.push_str(val);
        } else {
            resolved.push_str(part_trimmed);
        }
    }

    resolved
}

fn clean_description(desc: &str, cmd: &str) -> String {
    let desc = desc.trim().trim_matches('"').trim_matches('\'').trim();
    if desc.is_empty() || desc.starts_with("Run:") || desc.starts_with("Perform action:") {
        if cmd.contains("pick-color") {
            return "Color Picker".to_string();
        } else if cmd.contains("ocr") || cmd.contains("tesseract") {
            return "OCR Text Extractor (Screen Area)".to_string();
        } else if cmd.contains("clipboard_popup") {
            return "Toggle Clipboard Manager".to_string();
        } else if cmd.contains("emoji_popup") {
            return "Toggle Emoji Picker".to_string();
        } else if cmd.contains("volume_popup") {
            return "Toggle Volume Mixer".to_string();
        } else if cmd.contains("vm_popup") {
            return "Toggle VM Manager".to_string();
        } else if cmd.contains("network_popup") {
            return "Toggle Network Settings".to_string();
        } else if cmd.contains("bluetooth_popup") {
            return "Toggle Bluetooth Settings".to_string();
        } else if cmd.contains("brightness_popup") {
            return "Toggle Brightness Controls".to_string();
        } else if cmd.contains("notif_popup") {
            return "Toggle Notification Center".to_string();
        } else if cmd.contains("podman_popup") {
            return "Toggle Podman Dashboard".to_string();
        } else if cmd.contains("media_popup") {
            return "Toggle Media Center".to_string();
        } else if cmd.contains("wallpaper_switcher") {
            return "Toggle Wallpaper Switcher".to_string();
        } else if cmd.contains("colorscheme_popup") {
            return "Toggle Colorscheme Selector".to_string();
        } else if cmd.contains("workspace_popup") {
            return "Toggle Workspace Switcher".to_string();
        } else if cmd.contains("toggle_glass") {
            return "Toggle Blur/Glassmorphism Effect".to_string();
        } else if cmd.contains("pypr expose") {
            return "Toggle Window Overview (Expose)".to_string();
        } else if cmd.contains("pypr layout_center toggle") {
            return "Toggle Layout Center".to_string();
        } else if cmd.contains("pypr toggle term") {
            return "Toggle Dropdown Terminal".to_string();
        } else if cmd.contains("waybar_toggle") {
            return "Toggle Status Bar".to_string();
        } else if cmd.contains("hyprlock") {
            return "Lock Screen".to_string();
        } else if cmd.contains("osdctl caps toggle") {
            return "Toggle Caps Lock OSD".to_string();
        } else if cmd.contains("osdctl volume up") {
            return "Increase Volume".to_string();
        } else if cmd.contains("osdctl volume down") {
            return "Decrease Volume".to_string();
        } else if cmd.contains("osdctl volume mute") {
            return "Mute Audio".to_string();
        } else if cmd.contains("osdctl volume mic-mute") {
            return "Mute Microphone".to_string();
        } else if cmd.contains("osdctl brightness up") {
            return "Increase Screen Brightness".to_string();
        } else if cmd.contains("osdctl brightness down") {
            return "Decrease Screen Brightness".to_string();
        } else if cmd.contains("osdctl kbdbrightness up") {
            return "Increase Keyboard Brightness".to_string();
        } else if cmd.contains("osdctl kbdbrightness down") {
            return "Decrease Keyboard Brightness".to_string();
        } else if cmd.contains("playerctl next") {
            return "Next Track".to_string();
        } else if cmd.contains("playerctl play-pause") {
            return "Play/Pause Media".to_string();
        } else if cmd.contains("playerctl previous") {
            return "Previous Track".to_string();
        } else if cmd.contains("zen-browser") {
            return "Launch Zen Browser".to_string();
        } else if cmd.contains("code-insiders") {
            return "Launch VS Code Insiders".to_string();
        } else if cmd.contains("ghostty --class=ghostty.floating") {
            return "Launch Floating Ghostty".to_string();
        } else if cmd.contains("ghostty") {
            return "Launch Ghostty Terminal".to_string();
        } else if cmd.contains("kitty") {
            return "Launch Kitty Terminal".to_string();
        } else if cmd.contains("warp-terminal") {
            return "Launch Warp Terminal".to_string();
        } else if cmd.contains("thunar --class=thunar.floating") {
            return "Launch Floating File Manager".to_string();
        } else if cmd.contains("thunar") {
            return "Launch File Manager".to_string();
        } else if cmd.contains("rofi_wrap -show drun") {
            return "Open Application Menu".to_string();
        } else if cmd.contains("rofi_wrap -show recents") {
            return "Open Recent Documents".to_string();
        } else if cmd.contains("rofi_wrap -show power") {
            return "Open Power Menu".to_string();
        } else if cmd.contains("rofi_wrap -show sunset") {
            return "Open Night Light Controls".to_string();
        } else if cmd.contains("rofi_wrap -show ports") {
            return "Show Occupied Network Ports".to_string();
        } else if cmd.contains("rofi_wrap -show profile") {
            return "Open User Profile Settings".to_string();
        }
    }
    desc.to_string()
}

fn add_bind_to_categories(
    categories: &mut Vec<Category>,
    category_name: &str,
    keys: String,
    description: String,
    cmd: String,
) {
    for cat in categories.iter_mut() {
        if cat.category == category_name {
            cat.binds.push(Bind {
                keys,
                description,
                cmd,
            });
            return;
        }
    }
    categories.push(Category {
        category: category_name.to_string(),
        binds: vec![Bind {
            keys,
            description,
            cmd,
        }],
    });
}

fn parse_single_bind(
    bind_line: &str,
    current_category: &str,
    categories: &mut Vec<Category>,
    variables: &HashMap<String, String>,
    pending_comment: &str,
) {
    let args = match parse_balanced_args(bind_line) {
        Some(a) => a,
        None => return,
    };
    if args.len() < 2 {
        return;
    }

    let keys_expr = &args[0];
    let action_expr = &args[1];

    let mut inline_comment = String::new();
    if let Some(comment_idx) = bind_line.find(" --") {
        let cleaned = strip_lua_comments(bind_line);
        if cleaned.len() < bind_line.len() {
            inline_comment = bind_line[cleaned.len()..]
                .trim()
                .trim_start_matches('-')
                .trim()
                .to_string();
        }
    }

    let keys = evaluate_lua_expr(keys_expr, variables);
    let mut description = if !pending_comment.is_empty() {
        pending_comment.to_string()
    } else {
        inline_comment
    };

    let mut cmd = String::new();
    if action_expr.contains("exec_cmd") {
        if let Some(start_exec) = action_expr.find("exec_cmd(") {
            let inner_exec = &action_expr[start_exec + 9..];
            // Find balanced closing paren of exec_cmd
            let mut depth = 1;
            let mut end_exec = 0;
            let inner_chars: Vec<char> = inner_exec.chars().collect();
            for (idx, &c) in inner_chars.iter().enumerate() {
                if c == '(' {
                    depth += 1;
                } else if c == ')' {
                    depth -= 1;
                    if depth == 0 {
                        end_exec = idx;
                        break;
                    }
                }
            }
            let cmd_val = &inner_exec[..end_exec].trim();
            cmd = evaluate_lua_expr(cmd_val, variables);
            if description.is_empty() {
                description = format!("Run: {}", cmd);
            }
        }
    } else if action_expr.contains("window.close") {
        cmd = "hyprctl dispatch closewindow active".to_string();
        if description.is_empty() {
            description = "Close active window".to_string();
        }
    } else if action_expr.contains("window.float") {
        cmd = "hyprctl dispatch togglefloating".to_string();
        if description.is_empty() {
            description = "Toggle float layout".to_string();
        }
    } else if action_expr.contains("window.pseudo") {
        cmd = "hyprctl dispatch pseudotiled".to_string();
        if description.is_empty() {
            description = "Toggle pseudo layout".to_string();
        }
    } else if action_expr.contains("window.drag") {
        if description.is_empty() {
            description = "Drag window (mouse)".to_string();
        }
    } else if action_expr.contains("window.resize") {
        if description.is_empty() {
            description = "Resize window (mouse)".to_string();
        }
    } else if action_expr.contains("focus") {
        if action_expr.contains("direction") {
            if let Some(dir_start) = action_expr.find("direction") {
                let after_dir = &action_expr[dir_start..];
                let dir = after_dir
                    .split('"')
                    .nth(1)
                    .or_else(|| after_dir.split('\'').nth(1))
                    .unwrap_or("");
                let short_dir = match dir {
                    "left" => "l",
                    "right" => "r",
                    "up" => "u",
                    "down" => "d",
                    _ => dir,
                };
                cmd = format!("hyprctl dispatch movefocus {}", short_dir);
                if description.is_empty() {
                    description = format!("Focus window {}", dir);
                }
            }
        } else if action_expr.contains("workspace") {
            if let Some(ws_start) = action_expr.find("workspace") {
                let after_ws = &action_expr[ws_start..];
                let ws = after_ws
                    .split('=')
                    .nth(1)
                    .unwrap_or("")
                    .trim()
                    .trim_end_matches('}')
                    .trim()
                    .trim_matches('"')
                    .trim_matches('\'')
                    .trim();
                cmd = format!("hyprctl dispatch workspace {}", ws);
                if description.is_empty() {
                    description = format!("Switch to workspace {}", ws);
                }
            }
        } else if description.is_empty() {
            description = "Focus window/workspace".to_string();
        }
    } else if action_expr.contains("workspace.toggle_special") {
        if let Some(spec_start) = action_expr.find("toggle_special(") {
            let inner_spec = &action_expr[spec_start + 15..];
            let end_spec = inner_spec.find(')').unwrap_or(0);
            let spec_val = evaluate_lua_expr(&inner_spec[..end_spec], variables);
            cmd = format!("hyprctl dispatch togglespecialworkspace {}", spec_val);
            if description.is_empty() {
                description = format!("Toggle special workspace: {}", spec_val);
            }
        }
    } else if action_expr.contains("window.move") {
        if action_expr.contains("workspace") {
            if let Some(ws_start) = action_expr.find("workspace") {
                let after_ws = &action_expr[ws_start..];
                let ws = after_ws
                    .split('=')
                    .nth(1)
                    .unwrap_or("")
                    .trim()
                    .trim_end_matches('}')
                    .trim()
                    .trim_matches('"')
                    .trim_matches('\'')
                    .trim();
                cmd = format!("hyprctl dispatch movetoworkspace {}", ws);
                if description.is_empty() {
                    description = format!("Move window to workspace {}", ws);
                }
            }
        } else if description.is_empty() {
            description = "Move window".to_string();
        }
    } else if action_expr.contains("set_prop") {
        cmd = "hyprctl dispatch setprop active opaque toggle".to_string();
        if description.is_empty() {
            description = "Toggle window properties (e.g. opaque)".to_string();
        }
    } else if description.is_empty() {
        description = format!("Perform action: {}", action_expr);
    }

    let description = clean_description(&description, &cmd);
    add_bind_to_categories(categories, current_category, keys, description, cmd);
}

fn expand_workspaces_loop(
    loop_lines: &[String],
    current_category: &str,
    categories: &mut Vec<Category>,
    variables: &HashMap<String, String>,
) {
    for i in 1..=10 {
        let key = (i % 10).to_string();
        let mut local_vars = variables.clone();
        local_vars.insert("key".to_string(), key.clone());
        local_vars.insert("i".to_string(), i.to_string());

        for line in loop_lines {
            if line.contains("hl.bind") {
                let line_resolved = line
                    .replace(".. key", &format!(".. \"{}\"", key))
                    .replace("workspace = i", &format!("workspace = \"{}\"", i));
                parse_single_bind(
                    &line_resolved,
                    current_category,
                    categories,
                    &local_vars,
                    "",
                );
            }
        }
    }
}

pub fn parse_binds<P: AsRef<Path>>(filepath: P) -> io::Result<Vec<Category>> {
    let file = File::open(filepath)?;
    let reader = BufReader::new(file);
    let mut lines = Vec::new();
    for line in reader.lines() {
        lines.push(line?);
    }

    let mut variables = HashMap::new();
    variables.insert("mainMod".to_string(), "SUPER".to_string());

    let mut categories = Vec::new();
    let mut current_category = "General".to_string();
    let mut pending_comment = String::new();

    let mut i = 0;
    while i < lines.len() {
        let line = lines[i].trim();
        if line.is_empty() {
            pending_comment.clear();
            i += 1;
            continue;
        }

        // Parse Category Headers
        if line.starts_with('-') {
            // Check if matches category header pattern
            let cleaned = line.trim_matches('-');
            if !cleaned.trim().is_empty()
                && cleaned
                    .chars()
                    .all(|c| c.is_alphanumeric() || c.is_whitespace() || c == '_')
            {
                let cat = cleaned.trim();
                if cat.to_lowercase() != "keybindings" {
                    current_category = cat.to_string();
                }
                i += 1;
                continue;
            }
        }

        // Parse standard single line comment
        if line.starts_with("--") && !line.starts_with("---") {
            let comment_text = strip_lua_comments(line);
            if comment_text == line {
                pending_comment = line[2..].trim().to_string();
            } else {
                pending_comment = comment_text;
            }
            i += 1;
            continue;
        }

        // Parse local variables
        if line.starts_with("local ") {
            if let Some(eq_idx) = line.find('=') {
                let name = line[6..eq_idx].trim().to_string();
                let expr = &line[eq_idx + 1..].trim();
                let val = evaluate_lua_expr(expr, &variables);
                variables.insert(name, val);
                i += 1;
                continue;
            }
        }

        // Handle workspaces loop
        if line.contains("for i = 1, 10 do") {
            let mut loop_lines = Vec::new();
            i += 1;
            while i < lines.len() && !lines[i].contains("end") {
                loop_lines.push(lines[i].trim().to_string());
                i += 1;
            }
            expand_workspaces_loop(&loop_lines, &current_category, &mut categories, &variables);
            i += 1;
            continue;
        }

        // Parse hl.bind
        if line.contains("hl.bind(") {
            let mut full_bind_line = line.to_string();
            let start_idx = full_bind_line.find("hl.bind(").unwrap();
            let mut depth = 1;
            let mut idx = start_idx + 8;

            let mut chars: Vec<char> = full_bind_line.chars().collect();
            while idx < chars.len() && depth > 0 {
                let char = chars[idx];
                if char == '(' {
                    depth += 1;
                } else if char == ')' {
                    depth -= 1;
                }
                idx += 1;
            }

            while depth > 0 && i + 1 < lines.len() {
                i += 1;
                let next_line = lines[i].trim();
                full_bind_line.push(' ');
                full_bind_line.push_str(next_line);

                chars = full_bind_line.chars().collect();
                while idx < chars.len() && depth > 0 {
                    let char = chars[idx];
                    if char == '(' {
                        depth += 1;
                    } else if char == ')' {
                        depth -= 1;
                    }
                    idx += 1;
                }
            }

            parse_single_bind(
                &full_bind_line,
                &current_category,
                &mut categories,
                &variables,
                &pending_comment,
            );
            pending_comment.clear();
        }

        i += 1;
    }

    Ok(categories)
}

fn main() {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/parazeeknova".to_string());
    let binds_file = format!("{}/doty/.config/hypr/modules/binds.lua", home);
    let args: Vec<String> = std::env::args().collect();
    let filepath = if args.len() > 1 {
        &args[1]
    } else {
        &binds_file
    };

    match parse_binds(filepath) {
        Ok(result) => {
            if let Ok(json_str) = serde_json::to_string_pretty(&result) {
                println!("{}", json_str);
            }
        }
        Err(e) => {
            eprintln!("Failed to parse keybindings: {}", e);
            std::process::exit(1);
        }
    }
}
