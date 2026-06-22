use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize, Clone, Debug)]
struct ContributionDay {
    date: String,
    level: u32,
    count: u32,
}

#[derive(Serialize, Clone, Debug)]
struct ActivityItem {
    event_type: String,
    repo: String,
    description: String,
    time: String,
    count: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    total_commits: Option<u32>,
    #[serde(skip)]
    times: Vec<String>,
}

#[derive(Serialize, Debug)]
struct ContributionData {
    username: String,
    total_contributions: u32,
    days: Vec<ContributionDay>,
    activity: Vec<ActivityItem>,
}

#[derive(Deserialize, Debug)]
struct GithubEvent {
    #[serde(rename = "type")]
    event_type: String,
    repo: Repo,
    payload: Option<serde_json::Value>,
    created_at: String,
}

#[derive(Deserialize, Debug)]
struct Repo {
    name: String,
}

fn main() {
    let username = std::env::var("WABI_GITHUB_USER").unwrap_or_else(|_| String::new());
    if username.is_empty() {
        eprintln!("WABI_GITHUB_USER is not set");
        std::process::exit(1);
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let cache_path_str = format!("{home}/.cache/quickshell_github_graph.json");
    let cache_path = std::path::Path::new(&cache_path_str);

    let calendar_url = format!("https://github.com/users/{username}/contributions");
    let events_url = format!("https://api.github.com/users/{username}/events");

    let mut html = String::new();
    let mut events_json = String::new();
    let mut fetch_success = true;

    // Fetch calendar html
    if let Some(content) = wabi::run_cmd("curl", &["-sLfg", &calendar_url]) {
        html = content;
    } else {
        fetch_success = false;
    }

    // Fetch events json
    if fetch_success {
        if let Some(content) = wabi::run_cmd(
            "curl",
            &["-sfg", "-H", "User-Agent: quickshell-widget", &events_url],
        ) {
            events_json = content;
        } else {
            fetch_success = false;
        }
    }

    // Fallback to cache if network fetch failed
    if !fetch_success {
        if cache_path.exists()
            && let Ok(cached_data) = std::fs::read_to_string(cache_path)
        {
            println!("{cached_data}");
            return;
        }
        eprintln!("Failed to fetch contributions and no local cache is available.");
        std::process::exit(1);
    }

    let mut days = parse_contributions(&html);
    days.sort_by(|a, b| a.date.cmp(&b.date));
    let total_contributions: u32 = days.iter().map(|d| d.count).sum();
    let activity = parse_activity(&events_json);

    let data = ContributionData {
        username: username.to_string(),
        total_contributions,
        days,
        activity,
    };

    if let Ok(json) = serde_json::to_string(&data) {
        // Save to cache file
        if let Some(parent) = cache_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let _ = std::fs::write(cache_path, &json);
        // Output JSON
        println!("{json}");
    }
}

fn parse_contributions(html: &str) -> Vec<ContributionDay> {
    let mut days = Vec::new();
    let mut tooltips = HashMap::new();

    // Parse tooltips
    let mut pos = 0;
    while let Some(start_idx) = html[pos..].find("<tool-tip") {
        let abs_start = pos + start_idx;
        if let Some(end_idx) = html[abs_start..].find("</tool-tip>") {
            let abs_end = abs_start + end_idx;
            let tooltip_tag = &html[abs_start..abs_end + 11];

            if let Some(for_idx) = tooltip_tag.find("for=\"") {
                let id_start = for_idx + 5;
                if let Some(id_end) = tooltip_tag[id_start..].find("\"") {
                    let id = &tooltip_tag[id_start..id_start + id_end];
                    if let Some(close_tag_idx) = tooltip_tag.find(">") {
                        let text_start = close_tag_idx + 1;
                        let text_end = tooltip_tag.len() - 11;
                        if text_start < text_end {
                            let text = &tooltip_tag[text_start..text_end];
                            tooltips.insert(id.to_string(), text.to_string());
                        }
                    }
                }
            }
            pos = abs_end + 11;
        } else {
            break;
        }
    }

    // Parse td days
    pos = 0;
    while let Some(start_idx) = html[pos..].find("<td") {
        let abs_start = pos + start_idx;
        if let Some(end_idx) = html[abs_start..].find(">") {
            let abs_end = abs_start + end_idx;
            let td_tag = &html[abs_start..abs_end + 1];

            if td_tag.contains("ContributionCalendar-day") {
                let mut date = String::new();
                let mut level = 0;
                let mut id = String::new();

                if let Some(date_idx) = td_tag.find("data-date=\"") {
                    let s = date_idx + 11;
                    if let Some(e) = td_tag[s..].find("\"") {
                        date = td_tag[s..s + e].to_string();
                    }
                }

                if let Some(level_idx) = td_tag.find("data-level=\"") {
                    let s = level_idx + 12;
                    if let Some(e) = td_tag[s..].find("\"")
                        && let Ok(l) = td_tag[s..s + e].parse::<u32>()
                    {
                        level = l;
                    }
                }

                if let Some(id_idx) = td_tag.find("id=\"") {
                    let s = id_idx + 4;
                    if let Some(e) = td_tag[s..].find("\"") {
                        id = td_tag[s..s + e].to_string();
                    }
                }

                if !date.is_empty() {
                    let tooltip_text = tooltips.get(&id).cloned().unwrap_or_default();
                    let count = parse_count(&tooltip_text);
                    days.push(ContributionDay { date, level, count });
                }
            }
            pos = abs_end + 1;
        } else {
            break;
        }
    }

    days
}

fn parse_count(text: &str) -> u32 {
    let clean = text.trim();
    if clean.starts_with("No ") {
        0
    } else {
        if let Some(space_idx) = clean.find(' ') {
            clean[..space_idx].parse::<u32>().unwrap_or(0)
        } else {
            0
        }
    }
}

fn get_local_commit_count(repo_name: &str) -> Option<u32> {
    let parts: Vec<&str> = repo_name.split('/').collect();
    if parts.len() < 2 {
        return None;
    }
    let repo_basename = parts[1];
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());

    let paths = vec![
        format!("{home}/{repo_basename}"),
        format!("{home}/Repository/{repo_basename}"),
    ];

    for path_str in paths {
        let path = std::path::Path::new(&path_str);
        if path.join(".git").exists()
            && let Some(output) =
                wabi::run_cmd("git", &["-C", &path_str, "rev-list", "--count", "HEAD"])
            && let Ok(count) = output.trim().parse::<u32>()
        {
            return Some(count);
        }
    }
    None
}

fn parse_activity(json_str: &str) -> Vec<ActivityItem> {
    let events: Vec<GithubEvent> = serde_json::from_str(json_str).unwrap_or_default();
    let current_epoch = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();

    let raw_items: Vec<ActivityItem> = events
        .into_iter()
        .take(30)
        .map(|event| {
            let relative_time = format_relative_time(&event.created_at, current_epoch);
            let description = format_description(&event.event_type, event.payload.as_ref());
            let total_commits = get_local_commit_count(&event.repo.name);
            ActivityItem {
                event_type: event.event_type,
                repo: event.repo.name,
                description,
                time: relative_time.clone(),
                count: 1,
                total_commits,
                times: vec![relative_time],
            }
        })
        .collect();

    // Aggregate consecutive duplicates
    let mut aggregated: Vec<ActivityItem> = Vec::new();
    for item in raw_items {
        if let Some(last) = aggregated.last_mut()
            && last.event_type == item.event_type
            && last.repo == item.repo
            && last.description == item.description
        {
            last.count += 1;
            // Accumulate unique times
            if !last.times.contains(&item.time) {
                last.times.push(item.time);
            }
            continue;
        }
        aggregated.push(item);
    }

    // Format final aggregated times (join all times, truncating at 8)
    for item in &mut aggregated {
        if item.times.len() > 8 {
            let truncated = &item.times[..8];
            let remaining = item.times.len() - 8;
            item.time = format!("{}, +{} more", truncated.join(", "), remaining);
        } else {
            item.time = item.times.join(", ");
        }
    }

    aggregated
}

fn format_description(event_type: &str, payload: Option<&serde_json::Value>) -> String {
    match event_type {
        "PushEvent" => {
            let branch = payload
                .and_then(|p| p.get("ref"))
                .and_then(|r| r.as_str())
                .map(|r| r.replace("refs/heads/", ""))
                .unwrap_or_else(|| "main".to_string());
            format!("Pushed to `{branch}`")
        }
        "PullRequestEvent" => {
            let action = payload
                .and_then(|p| p.get("action"))
                .and_then(|a| a.as_str())
                .unwrap_or("opened");
            let is_merged = payload
                .and_then(|p| p.get("pull_request"))
                .and_then(|pr| pr.get("merged"))
                .and_then(|m| m.as_bool())
                .unwrap_or(false);

            if is_merged {
                "Merged pull request".to_string()
            } else {
                format!("{} pull request", uppercase_first(action))
            }
        }
        "IssuesEvent" => {
            let action = payload
                .and_then(|p| p.get("action"))
                .and_then(|a| a.as_str())
                .unwrap_or("opened");
            format!("{} issue", uppercase_first(action))
        }
        "CreateEvent" => {
            let ref_type = payload
                .and_then(|p| p.get("ref_type"))
                .and_then(|t| t.as_str())
                .unwrap_or("repository");
            format!("Created {ref_type}")
        }
        "DeleteEvent" => {
            let ref_type = payload
                .and_then(|p| p.get("ref_type"))
                .and_then(|t| t.as_str())
                .unwrap_or("branch");
            format!("Deleted {ref_type}")
        }
        "IssueCommentEvent" => "Commented on issue".to_string(),
        "WatchEvent" => "Starred repository".to_string(),
        "ForkEvent" => "Forked repository".to_string(),
        _ => event_type.replace("Event", ""),
    }
}

fn uppercase_first(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
    }
}

fn format_relative_time(created_at: &str, current_epoch: u64) -> String {
    let Some(epoch) = date_to_epoch(created_at) else {
        return "recently".to_string();
    };

    if current_epoch < epoch {
        return "just now".to_string();
    }

    let diff = current_epoch - epoch;
    if diff < 60 {
        "just now".to_string()
    } else if diff < 3600 {
        let mins = diff / 60;
        format!("{mins}m ago")
    } else if diff < 86400 {
        let hours = diff / 3600;
        format!("{hours}h ago")
    } else {
        let days = diff / 86400;
        if days == 1 {
            "yesterday".to_string()
        } else {
            format!("{days}d ago")
        }
    }
}

fn date_to_epoch(s: &str) -> Option<u64> {
    if s.len() < 19 {
        return None;
    }
    let year = s[0..4].parse::<u64>().ok()?;
    let month = s[5..7].parse::<u64>().ok()?;
    let day = s[8..10].parse::<u64>().ok()?;
    let hour = s[11..13].parse::<u64>().ok()?;
    let min = s[14..16].parse::<u64>().ok()?;
    let sec = s[17..19].parse::<u64>().ok()?;

    let days_in_months = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    let mut days = (year - 1970) * 365;
    for y in 1970..year {
        if (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0) {
            days += 1;
        }
    }

    for m in 1..month {
        days += days_in_months[m as usize];
        if m == 2 && ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
            days += 1;
        }
    }

    days += day - 1;

    let seconds = days * 86400 + hour * 3600 + min * 60 + sec;
    Some(seconds)
}
