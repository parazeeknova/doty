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
pub struct Category {
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
        } else if char == '-'
            && k < chars.len() - 1
            && chars[k + 1] == '-'
            && !in_single
            && !in_double
        {
            return line[..k].trim().to_string();
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
    let mut in_single = false;
    let mut in_double = false;

    while i < chars.len() && depth > 0 {
        let char = chars[i];
        // Track quote state
        if char == '\'' && !in_double {
            in_single = !in_single;
        } else if char == '"' && !in_single {
            in_double = !in_double;
        }
        // Only count parens outside of strings
        if !in_single && !in_double {
            if char == '(' {
                depth += 1;
            } else if char == ')' {
                depth -= 1;
                if depth == 0 {
                    break;
                }
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
        } else if char == '"' && (j == 0 || inner_chars[j - 1] != '\\') && !in_single_quote {
            in_double_quote = !in_double_quote;
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

fn find_or_separator(expr: &str) -> Option<usize> {
    let chars: Vec<char> = expr.chars().collect();
    let mut in_single = false;
    let mut in_double = false;
    let mut i = 0;
    while i < chars.len() {
        let c = chars[i];
        if c == '\'' && !in_double {
            in_single = !in_single;
        } else if c == '"' && !in_single {
            in_double = !in_double;
        } else if !in_single && !in_double && c == 'o' && i + 1 < chars.len() && chars[i + 1] == 'r'
        {
            // Check word boundaries
            let before_ok = i == 0 || !chars[i - 1].is_alphanumeric();
            let after_ok = i + 2 >= chars.len() || !chars[i + 2].is_alphanumeric();
            if before_ok && after_ok {
                // Make sure this isn't inside a string or part of a variable name
                return Some(i);
            }
        }
        i += 1;
    }
    None
}

fn evaluate_lua_expr(expr: &str, variables: &HashMap<String, String>) -> String {
    let expr = strip_lua_comments(expr);

    // Handle "or" fallback: try left side, if empty use right side
    if let Some(or_idx) = find_or_separator(&expr) {
        let left = expr[..or_idx].trim();
        let right = expr[or_idx + 2..].trim();
        let left_val = evaluate_lua_expr_single(left, variables);
        if !left_val.is_empty() && !left_val.contains("os.getenv") {
            return left_val;
        }
        // Left side resolved to empty or unresolved env var, try right side
        // Strip outer parens from right side if present
        let right = if right.starts_with('(') && right.ends_with(')') {
            &right[1..right.len() - 1]
        } else {
            right
        };
        return evaluate_lua_expr(right, variables);
    }

    evaluate_lua_expr_single(&expr, variables)
}

fn evaluate_lua_expr_single(expr: &str, variables: &HashMap<String, String>) -> String {
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
        } else if char == '"' && (k == 0 || chars[k - 1] != '\\') && !in_single {
            in_double = !in_double;
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
        } else if let Some(inner) = part_trimmed.strip_prefix("os.getenv(") {
            // Handle os.getenv("VAR") or os.getenv('VAR')
            let inner = inner.trim().trim_end_matches(')');
            let var_name = inner.trim_matches('"').trim_matches('\'');
            if let Ok(val) = std::env::var(var_name) {
                resolved.push_str(&val);
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
        } else if cmd.contains("shortcut_popup") {
            return "Toggle Shortcut Reference".to_string();
        } else if cmd.contains("workspace_popup") {
            return "Toggle Workspace Switcher".to_string();
        } else if cmd.contains("tray_popup") {
            return "Toggle System Tray".to_string();
        } else if cmd.contains("battery_popup") {
            return "Toggle Battery Monitor".to_string();
        } else if cmd.contains("toggle-glass") || cmd.contains("toggle_glass") {
            return "Toggle Blur/Glassmorphism Effect".to_string();
        } else if cmd.contains("pypr expose") {
            return "Toggle Window Overview (Expose)".to_string();
        } else if cmd.contains("pypr layout_center toggle") {
            return "Toggle Layout Center".to_string();
        } else if cmd.contains("pypr toggle term") {
            return "Toggle Dropdown Terminal".to_string();
        } else if cmd.contains("waybar_toggle") {
            return "Toggle Status Bar".to_string();
        } else if cmd.contains("toggle_widgets") {
            return "Toggle Widgets".to_string();
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
        } else if cmd.contains("vivaldi-stable") {
            return "Launch Vivaldi Browser".to_string();
        } else if cmd.contains("brave") {
            return "Launch Brave Browser".to_string();
        } else if cmd.contains("code-insiders") {
            return "Launch VS Code Insiders".to_string();
        } else if cmd.contains("code") && cmd.contains("focus") {
            return "Launch/Focus VS Code".to_string();
        } else if cmd.contains("spotify") {
            return "Launch/Focus Spotify".to_string();
        } else if cmd.contains("gitkraken") {
            return "Toggle GitKraken".to_string();
        } else if cmd.contains("helium") {
            return "Toggle Helium Browser".to_string();
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
        } else if cmd.contains("apps_popup") {
            return "Open Application Menu".to_string();
        } else if cmd.contains("recents_popup") {
            return "Open Recent Documents".to_string();
        } else if cmd.contains("power_popup") {
            return "Open Power Menu".to_string();
        } else if cmd.contains("sunset_popup") {
            return "Open Night Light Controls".to_string();
        } else if cmd.contains("profile_popup") {
            return "Open Profile Switcher".to_string();
        } else if cmd.contains("ports_popup") {
            return "Show Occupied Network Ports".to_string();
        } else if cmd.contains("uwsm stop") || cmd.contains("uwsm check") {
            return "Logout / Exit".to_string();
        } else if cmd.contains("scrolloverview") {
            return "Toggle Window Overview".to_string();
        } else if cmd.contains("column_width") {
            return "Cycle Column Width".to_string();
        } else if cmd.contains("grim") && cmd.contains("slurp") && cmd.contains("swappy") {
            return "Screenshot Region (Edit)".to_string();
        } else if cmd.contains("grim") && cmd.contains("slurp") {
            return "Screenshot Region".to_string();
        } else if cmd.contains("grim") {
            return "Screenshot Full Screen".to_string();
        } else if cmd.contains("theme_switcher") {
            return "Toggle Glassmorphism".to_string();
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
    if let Some(_comment_idx) = bind_line.find(" --") {
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
    if action_expr.contains("focus_or_launch") {
        if let Some(start_fn) = action_expr.find("focus_or_launch(") {
            let inner = &action_expr[start_fn + 16..];
            let mut depth = 1;
            let mut end_idx = 0;
            let inner_chars: Vec<char> = inner.chars().collect();
            for (idx, &c) in inner_chars.iter().enumerate() {
                if c == '(' {
                    depth += 1;
                } else if c == ')' {
                    depth -= 1;
                    if depth == 0 {
                        end_idx = idx;
                        break;
                    }
                }
            }
            let fn_args_str = &inner[..end_idx];
            let fn_args: Vec<&str> = fn_args_str.split(',').map(|s| s.trim()).collect();
            if fn_args.len() >= 2 {
                let class = fn_args[0].trim_matches('"').trim_matches('\'');
                let launch_cmd = evaluate_lua_expr(fn_args[1], variables);
                cmd = launch_cmd.clone();
                if description.is_empty() {
                    let app_name = class.split('-').next().unwrap_or(class);
                    let capitalized: String = app_name
                        .chars()
                        .enumerate()
                        .map(|(i, c)| {
                            if i == 0 {
                                c.to_uppercase().to_string()
                            } else {
                                c.to_string()
                            }
                        })
                        .collect();
                    description = format!("Launch/Focus {}", capitalized);
                }
            }
        }
    } else if action_expr.contains("exec_cmd") {
        if let Some(start_exec) = action_expr.find("exec_cmd(") {
            let inner_exec = &action_expr[start_exec + 9..];
            // Find balanced closing paren of exec_cmd, skipping parens inside strings and $()
            let mut depth = 1;
            let mut end_exec = 0;
            let mut in_single = false;
            let mut in_double = false;
            let mut dollar_paren_depth = 0;
            let inner_chars: Vec<char> = inner_exec.chars().collect();
            let mut idx = 0;
            while idx < inner_chars.len() {
                let c = inner_chars[idx];
                // Track quote state
                if c == '\'' && !in_double {
                    in_single = !in_single;
                } else if c == '"' && !in_single {
                    in_double = !in_double;
                }
                // Track $(...) shell command substitution
                if !in_single
                    && !in_double
                    && c == '$'
                    && idx + 1 < inner_chars.len()
                    && inner_chars[idx + 1] == '('
                {
                    dollar_paren_depth += 1;
                    idx += 1; // skip the '(' on next iteration
                } else if !in_single && !in_double && dollar_paren_depth > 0 && c == '(' {
                    dollar_paren_depth += 1;
                } else if !in_single && !in_double && dollar_paren_depth > 0 && c == ')' {
                    dollar_paren_depth -= 1;
                } else if !in_single && !in_double && dollar_paren_depth == 0 {
                    // Only count parens outside of strings and $()
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
                idx += 1;
            }
            let cmd_val = &inner_exec[..end_exec].trim();
            cmd = evaluate_lua_expr(cmd_val, variables);
            if description.is_empty() {
                description = format!("Run: {}", cmd);
            }
        }
    } else if action_expr.contains("window.cycle_next") {
        let noloop = action_expr.contains("noloop");
        if action_expr.contains("prev") {
            cmd = if noloop {
                "hyprctl dispatch cyclenext prev noloop".to_string()
            } else {
                "hyprctl dispatch cyclenext prev".to_string()
            };
            if description.is_empty() {
                description = "Focus previous window".to_string();
            }
        } else {
            cmd = if noloop {
                "hyprctl dispatch cyclenext noloop".to_string()
            } else {
                "hyprctl dispatch cyclenext".to_string()
            };
            if description.is_empty() {
                description = "Focus next window".to_string();
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
        if action_expr.contains("x =") || action_expr.contains("y =") {
            let mut x_val = "0";
            let mut y_val = "0";
            if let Some(x_idx) = action_expr.find("x =") {
                let s = &action_expr[x_idx + 3..];
                x_val = s
                    .split(',')
                    .next()
                    .unwrap_or("0")
                    .trim()
                    .trim_end_matches('}')
                    .trim();
            }
            if let Some(y_idx) = action_expr.find("y =") {
                let s = &action_expr[y_idx + 3..];
                y_val = s
                    .split(',')
                    .next()
                    .unwrap_or("0")
                    .trim()
                    .trim_end_matches('}')
                    .trim();
            }
            cmd = format!("hyprctl dispatch resizeactive {} {}", x_val, y_val);
            if description.is_empty() {
                description = format!("Resize window by {}, {}", x_val, y_val);
            }
        } else if description.is_empty() {
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
                // Extract workspace value: find content between quotes after '='
                let ws = if let Some(eq_pos) = after_ws.find('=') {
                    let after_eq = &after_ws[eq_pos + 1..];
                    let after_eq = after_eq.trim();
                    // Try to extract quoted value
                    if let Some(start_q) = after_eq.find('"') {
                        let after_start = &after_eq[start_q + 1..];
                        if let Some(end_q) = after_start.find('"') {
                            after_start[..end_q].to_string()
                        } else {
                            after_eq
                                .trim_end_matches('}')
                                .trim()
                                .trim_matches('"')
                                .trim_matches('\'')
                                .trim()
                                .to_string()
                        }
                    } else if let Some(start_q) = after_eq.find('\'') {
                        let after_start = &after_eq[start_q + 1..];
                        if let Some(end_q) = after_start.find('\'') {
                            after_start[..end_q].to_string()
                        } else {
                            after_eq
                                .trim_end_matches('}')
                                .trim()
                                .trim_matches('"')
                                .trim_matches('\'')
                                .trim()
                                .to_string()
                        }
                    } else {
                        // Unquoted value (number)
                        after_eq
                            .split(['}', ')', ','])
                            .next()
                            .unwrap_or("")
                            .trim()
                            .to_string()
                    }
                } else {
                    String::new()
                };
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
                // Extract workspace value: find content between quotes after '='
                let ws = if let Some(eq_pos) = after_ws.find('=') {
                    let after_eq = &after_ws[eq_pos + 1..];
                    let after_eq = after_eq.trim();
                    if let Some(start_q) = after_eq.find('"') {
                        let after_start = &after_eq[start_q + 1..];
                        if let Some(end_q) = after_start.find('"') {
                            after_start[..end_q].to_string()
                        } else {
                            after_eq
                                .trim_end_matches('}')
                                .trim()
                                .trim_matches('"')
                                .trim_matches('\'')
                                .trim()
                                .to_string()
                        }
                    } else if let Some(start_q) = after_eq.find('\'') {
                        let after_start = &after_eq[start_q + 1..];
                        if let Some(end_q) = after_start.find('\'') {
                            after_start[..end_q].to_string()
                        } else {
                            after_eq
                                .trim_end_matches('}')
                                .trim()
                                .trim_matches('"')
                                .trim_matches('\'')
                                .trim()
                                .to_string()
                        }
                    } else {
                        after_eq
                            .split(['}', ')', ','])
                            .next()
                            .unwrap_or("")
                            .trim()
                            .to_string()
                    }
                } else {
                    String::new()
                };
                cmd = format!("hyprctl dispatch movetoworkspace {}", ws);
                if description.is_empty() {
                    description = format!("Move window to workspace {}", ws);
                }
            }
        } else if description.is_empty() {
            description = "Move window".to_string();
        }
    } else if action_expr.contains("layout") {
        // Handle layout actions like swapcol
        if action_expr.contains("swapcol") {
            let dir = if action_expr.contains("swapcol l") || action_expr.contains("swapcol \"l\"")
            {
                "left"
            } else if action_expr.contains("swapcol r") || action_expr.contains("swapcol \"r\"") {
                "right"
            } else {
                "column"
            };
            cmd = format!(
                "hyprctl dispatch swapcolumn {}",
                if dir == "left" { "l" } else { "r" }
            );
            if description.is_empty() {
                description = format!("Swap column {}", dir);
            }
        } else {
            if description.is_empty() {
                description = "Layout action".to_string();
            }
        }
    } else if action_expr.contains("set_prop") {
        cmd = "hyprctl dispatch setprop active opaque toggle".to_string();
        if description.is_empty() {
            description = "Toggle window properties (e.g. opaque)".to_string();
        }
    } else if action_expr.contains("function()") {
        if action_expr.contains("scrolloverview") {
            cmd = "hyprctl dispatch overview:toggle".to_string();
            if description.is_empty() {
                description = "Toggle Window Overview".to_string();
            }
        } else if action_expr.contains("column_width") {
            if description.is_empty() {
                description = "Cycle Column Width".to_string();
            }
        } else {
            if description.is_empty() {
                description = "Custom action".to_string();
            }
        }
    } else if description.is_empty() {
        description = format!("Perform action: {}", action_expr);
    }

    let description = clean_description(&description, &cmd);
    // Override screenshot descriptions based on bind line content
    let description = if bind_line.contains("swappy") {
        "Screenshot Region (Edit)".to_string()
    } else if bind_line.contains("slurp") && !bind_line.contains("tesseract") {
        if description == "Screenshot Full Screen" || description.starts_with("Run:") {
            "Screenshot Region".to_string()
        } else {
            description
        }
    } else if bind_line.contains("Print")
        && bind_line.contains("grim")
        && !bind_line.contains("slurp")
    {
        "Screenshot Full Screen".to_string()
    } else {
        description
    };
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

        let mut j = 0;
        while j < loop_lines.len() {
            let line = &loop_lines[j];
            if line.contains("hl.bind") {
                let mut full_bind_line = line.to_string();
                let start_idx = full_bind_line.find("hl.bind(").unwrap();
                let mut depth = 1;
                let mut idx = start_idx + 8;

                let mut chars: Vec<char> = full_bind_line.chars().collect();
                while idx < chars.len() && depth > 0 {
                    let c = chars[idx];
                    if c == '(' {
                        depth += 1;
                    } else if c == ')' {
                        depth -= 1;
                    }
                    idx += 1;
                }

                while depth > 0 && j + 1 < loop_lines.len() {
                    j += 1;
                    let next_line = &loop_lines[j];
                    full_bind_line.push(' ');
                    full_bind_line.push_str(next_line);

                    chars = full_bind_line.chars().collect();
                    while idx < chars.len() && depth > 0 {
                        let c = chars[idx];
                        if c == '(' {
                            depth += 1;
                        } else if c == ')' {
                            depth -= 1;
                        }
                        idx += 1;
                    }
                }

                let line_resolved = full_bind_line
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
            j += 1;
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
        // Match lines like "----  Applications ---" or "-- Quickshell popups"
        // Must start with at least 2 dashes, and the remaining text after removing dashes
        // must be non-empty and only contain alphanumeric, whitespace, or underscore chars
        if line.starts_with("--") {
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

        // Parse local variables (skip if line contains hl.bind - handle as bind instead)
        if line.starts_with("local ")
            && !line.contains("hl.bind(")
            && let Some(eq_idx) = line.find('=')
        {
            let name = line[6..eq_idx].trim().to_string();
            let expr = &line[eq_idx + 1..].trim();
            let val = evaluate_lua_expr(expr, &variables);
            variables.insert(name, val);
            i += 1;
            continue;
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
    let dotfiles = std::env::var("WABI_DOTFILES_DIR").unwrap_or_else(|_| {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        format!("{home}/doty")
    });
    let binds_file = format!("{dotfiles}/.config/hypr/modules/binds.lua");
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_temp_lua(content: &str) -> tempfile::NamedTempFile {
        let mut f = tempfile::NamedTempFile::new().unwrap();
        f.write_all(content.as_bytes()).unwrap();
        f
    }

    #[test]
    fn strip_comments_removes_line_comment() {
        assert_eq!(strip_lua_comments("\"hello\" -- world"), "\"hello\"");
        assert_eq!(
            strip_lua_comments("  key = 'val'  -- explanation"),
            "key = 'val'"
        );
    }

    #[test]
    fn strip_comments_preserves_strings_with_dashes() {
        assert_eq!(strip_lua_comments("'hello--world'"), "'hello--world'");
        assert_eq!(strip_lua_comments("\"hello--world\""), "\"hello--world\"");
    }

    #[test]
    fn strip_comments_no_comment_returns_trimmed() {
        assert_eq!(strip_lua_comments("  just a value  "), "just a value");
        assert_eq!(strip_lua_comments(" 'quoted' "), "'quoted'");
    }

    #[test]
    fn strip_comments_preserves_strings_with_escaped_quotes() {
        assert_eq!(strip_lua_comments("'o\\'clock' -- time"), "'o\\'clock'");
    }

    #[test]
    fn evaluate_lua_expr_resolves_string_literals() {
        let vars = HashMap::new();
        assert_eq!(evaluate_lua_expr("'hello'", &vars), "hello");
        assert_eq!(evaluate_lua_expr("\"world\"", &vars), "world");
    }

    #[test]
    fn evaluate_lua_expr_resolves_variable_concatenation() {
        let mut vars = HashMap::new();
        vars.insert("mainMod".to_string(), "SUPER".to_string());
        vars.insert("terminal".to_string(), "uwsm app -- ghostty".to_string());
        assert_eq!(
            evaluate_lua_expr("mainMod .. ' + RETURN'", &vars),
            "SUPER + RETURN"
        );
        assert_eq!(
            evaluate_lua_expr("\"uwsm app -- \" .. terminal", &vars),
            "uwsm app -- uwsm app -- ghostty"
        );
    }

    #[test]
    fn evaluate_lua_expr_handles_empty_parts() {
        let vars = HashMap::new();
        assert_eq!(evaluate_lua_expr("", &vars), "");
        assert_eq!(evaluate_lua_expr("'x' .. 'y'", &vars), "xy");
    }

    #[test]
    fn parse_binds_parses_categories_and_keys() {
        let f = write_temp_lua(
            "local mainMod = 'SUPER'\n\
             ---------------------\n\
             ---  Applications ---\n\
             ---------------------\n\
             hl.bind(mainMod .. ' + RETURN', hl.dsp.exec_cmd('uwsm app -- ghostty'))\n\
             hl.bind(mainMod .. ' + T', hl.dsp.exec_cmd('uwsm app -- kitty'))\n\
             ---------------------\n\
             ---    Windows    ---\n\
             ---------------------\n\
             hl.bind(mainMod .. ' + Q', hl.dsp.window.close())\n",
        );

        let result = parse_binds(f.path()).unwrap();
        assert_eq!(result.len(), 2);

        let apps = &result[0];
        assert_eq!(apps.category, "Applications");
        assert_eq!(apps.binds.len(), 2);
        assert_eq!(apps.binds[0].keys, "SUPER + RETURN");
        assert!(apps.binds[0].cmd.contains("ghostty"));
        assert_eq!(apps.binds[1].keys, "SUPER + T");
        assert!(apps.binds[1].cmd.contains("kitty"));

        let windows = &result[1];
        assert_eq!(windows.category, "Windows");
        assert_eq!(windows.binds.len(), 1);
        assert_eq!(windows.binds[0].keys, "SUPER + Q");
    }

    #[test]
    fn parse_binds_expands_workspaces_loop() {
        let f = write_temp_lua(
            "---------------------\n\
             ---  Workspaces   ---\n\
             ---------------------\n\
             local mainMod = 'SUPER'\n\
             for i = 1, 10 do\n\
               local key = i % 10\n\
               hl.bind(mainMod .. ' + ' .. key, hl.dsp.focus({workspace = i}))\n\
             end\n",
        );

        let result = parse_binds(f.path()).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].binds.len(), 10);
        assert_eq!(result[0].binds[0].keys, "SUPER + 1");
        assert_eq!(result[0].binds[9].keys, "SUPER + 0");
    }

    #[test]
    fn parse_binds_skips_keybindings_header() {
        let f = write_temp_lua(
            "---------------------\n\
             ---- Keybindings ----\n\
             ---------------------\n\
             local mainMod = 'SUPER'\n\
             hl.bind(mainMod .. ' + X', hl.dsp.exec_cmd('cmd'))\n",
        );

        let result = parse_binds(f.path()).unwrap();
        // "Keybindings" header should be skipped, bind goes to "General"
        assert_eq!(result[0].category, "General");
        assert_eq!(result[0].binds.len(), 1);
    }

    #[test]
    fn parse_binds_handles_empty_file() {
        let f = write_temp_lua("");
        let result = parse_binds(f.path()).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn parse_binds_handles_missing_file() {
        assert!(parse_binds("/tmp/no-such-binds-file-nonexistent.lua").is_err());
    }

    #[test]
    fn parse_balanced_args_splits_arguments() {
        let args =
            parse_balanced_args("hl.bind(mainMod .. ' + K', hl.dsp.exec_cmd(terminal))").unwrap();
        assert_eq!(args.len(), 2);
        assert!(args[0].contains("mainMod"));
        assert!(args[1].contains("exec_cmd"));
    }

    #[test]
    fn parse_balanced_args_handles_nested_braces() {
        let args = parse_balanced_args(
            "hl.bind(SUPER .. ' + F', hl.dsp.window.move({workspace = 'special:magic'}))",
        )
        .unwrap();
        assert_eq!(args.len(), 2);
        assert!(args[1].contains("workspace"));
    }

    #[test]
    fn parse_balanced_args_handles_release_modifier() {
        let args = parse_balanced_args(
            "hl.bind('SUPER_L', hl.dsp.exec_cmd('cmd'), {release = true, ignore_mods = true})",
        )
        .unwrap();
        assert_eq!(args.len(), 3);
    }

    #[test]
    fn parse_balanced_args_none_for_non_bind() {
        assert!(parse_balanced_args("  -- just a comment").is_none());
    }

    #[test]
    fn evaluate_lua_expr_handles_unknown_variable_as_is() {
        let vars = HashMap::new();
        assert_eq!(evaluate_lua_expr("unknownVar", &vars), "unknownVar");
    }
}
