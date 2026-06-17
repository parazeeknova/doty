use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Deserialize)]
struct Owner {
    login: String,
    #[serde(rename = "type")]
    owner_type: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct GitRepo {
    name: String,
    full_name: String,
    #[serde(default)]
    description: String,
    #[serde(default)]
    language: String,
    #[serde(default, alias = "stargazers_count")]
    stars: u32,
    #[serde(default)]
    forks: u32,
    #[serde(default)]
    private: bool,
    #[serde(default)]
    owner_login: String,
    #[serde(default)]
    owner_type: String,
    #[serde(default, alias = "html_url")]
    html_url: String,
    #[serde(default, alias = "updated_at")]
    updated_at: String,
    #[serde(default, alias = "default_branch")]
    default_branch: String,
    #[serde(default)]
    topics: Vec<String>,
}

#[derive(Deserialize)]
struct RawGitRepo {
    name: String,
    full_name: String,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    language: Option<String>,
    #[serde(default, alias = "stargazers_count")]
    stars: u32,
    #[serde(default)]
    forks: u32,
    #[serde(default)]
    private: bool,
    owner: Option<Owner>,
    #[serde(default, alias = "html_url")]
    html_url: String,
    #[serde(default, alias = "updated_at")]
    updated_at: String,
    #[serde(default, alias = "default_branch")]
    default_branch: String,
    #[serde(default)]
    topics: Vec<String>,
}

impl From<RawGitRepo> for GitRepo {
    fn from(r: RawGitRepo) -> Self {
        GitRepo {
            name: r.name,
            full_name: r.full_name,
            description: r.description.unwrap_or_default(),
            language: r.language.unwrap_or_default(),
            stars: r.stars,
            forks: r.forks,
            private: r.private,
            owner_login: r
                .owner
                .as_ref()
                .map(|o| o.login.clone())
                .unwrap_or_default(),
            owner_type: r
                .owner
                .as_ref()
                .map(|o| o.owner_type.clone())
                .unwrap_or_default(),
            html_url: r.html_url,
            updated_at: r.updated_at,
            default_branch: r.default_branch,
            topics: r.topics,
        }
    }
}

fn get_token() -> Option<String> {
    // Try env var first
    if let Ok(token) = std::env::var("WABI_GITHUB_TOKEN") {
        if !token.is_empty() {
            return Some(token);
        }
    }

    // Fallback: read from mcp-env.fish
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let env_path = format!("{}/.config/fish/conf.d/mcp-env.fish", home);
    if let Ok(content) = fs::read_to_string(&env_path) {
        for line in content.lines() {
            let line = line.trim();
            if line.contains("WABI_GITHUB_TOKEN") {
                if let Some(start) = line.find('"') {
                    if let Some(end) = line[start + 1..].find('"') {
                        let token = &line[start + 1..start + 1 + end];
                        if !token.is_empty() {
                            return Some(token.to_string());
                        }
                    }
                }
            }
        }
    }

    None
}

fn github_get(url: &str, token: Option<&str>) -> Option<String> {
    let mut args = vec!["-sLfg", "-H", "Accept: application/vnd.github+json"];

    let auth_header;
    if let Some(t) = token {
        auth_header = format!("Authorization: Bearer {}", t);
        args.push("-H");
        args.push(&auth_header);
    }

    args.push(url);

    let output = Command::new("curl").args(&args).output().ok()?;
    if output.status.success() {
        String::from_utf8(output.stdout).ok()
    } else {
        None
    }
}

fn fetch_user_repos(token: &str) -> Vec<GitRepo> {
    let mut all_repos = Vec::new();
    let mut page = 1;

    loop {
        let url = format!(
            "https://api.github.com/user/repos?per_page=100&page={}&sort=updated&direction=desc",
            page
        );

        let Some(json) = github_get(&url, Some(token)) else {
            break;
        };

        let raw: Vec<RawGitRepo> = serde_json::from_str(&json).unwrap_or_default();
        if raw.is_empty() {
            break;
        }

        all_repos.extend(raw.into_iter().map(GitRepo::from));
        page += 1;

        if page > 5 {
            break;
        }
    }

    all_repos
}

fn search_repos(query: &str, token: Option<&str>) -> Vec<GitRepo> {
    let encoded: String = query
        .bytes()
        .map(|b| match b {
            b' ' => '+'.to_string(),
            b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                (b as char).to_string()
            }
            _ => format!("%{:02X}", b),
        })
        .collect();

    let url = format!(
        "https://api.github.com/search/repositories?q={}&sort=stars&order=desc&per_page=25",
        encoded
    );

    let Some(json) = github_get(&url, token) else {
        return Vec::new();
    };

    #[derive(Deserialize)]
    struct SearchResult {
        #[serde(default)]
        items: Vec<RawGitRepo>,
    }

    let result: SearchResult = serde_json::from_str(&json).unwrap_or(SearchResult {
        items: Vec::new(),
    });

    result.items.into_iter().map(GitRepo::from).collect()
}

#[derive(Serialize, Deserialize)]
struct CachedRepos {
    timestamp: u64,
    repos: Vec<GitRepo>,
}

fn cache_path() -> std::path::PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    Path::new(&home).join(".cache/quickshell/github_repos.json")
}

fn save_repos_cache(repos: &[GitRepo]) {
    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let cached = CachedRepos {
        timestamp: ts,
        repos: repos.to_vec(),
    };
    let _ = fs::create_dir_all(cache_path().parent().unwrap());
    if let Ok(json) = serde_json::to_string(&cached) {
        let _ = fs::write(cache_path(), json);
    }
}

fn load_repos_cache(max_age_secs: u64) -> Option<Vec<GitRepo>> {
    let content = fs::read_to_string(cache_path()).ok()?;
    let cached: CachedRepos = serde_json::from_str(&content).ok()?;
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    if now.saturating_sub(cached.timestamp) > max_age_secs {
        return None;
    }
    Some(cached.repos)
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let token = get_token();

    // Handle --list-repos
    if args.len() > 1 && args[1] == "--list-repos" {
        // Check cache first (valid for 1 hour)
        if let Some(cached) = load_repos_cache(3600) {
            let _ = serde_json::to_writer(std::io::stdout(), &cached);
            return;
        }

        // Cache miss or expired — fetch from API
        if let Some(ref t) = token {
            let repos = fetch_user_repos(t);
            save_repos_cache(&repos);
            let _ = serde_json::to_writer(std::io::stdout(), &repos);
        } else {
            // No token and no valid cache — return empty
            let repos: Vec<GitRepo> = Vec::new();
            let _ = serde_json::to_writer(std::io::stdout(), &repos);
        }
        return;
    }

    // Handle --refresh-repos (force fetch, ignore cache)
    if args.len() > 1 && args[1] == "--refresh-repos" {
        if let Some(ref t) = token {
            let repos = fetch_user_repos(t);
            save_repos_cache(&repos);
            let _ = serde_json::to_writer(std::io::stdout(), &repos);
        } else {
            let repos = load_repos_cache(u64::MAX).unwrap_or_default();
            let _ = serde_json::to_writer(std::io::stdout(), &repos);
        }
        return;
    }

    // Handle --search-repos <query>
    if args.len() > 2 && args[1] == "--search-repos" {
        let query = &args[2];
        let repos = search_repos(query, token.as_deref());
        let _ = serde_json::to_writer(std::io::stdout(), &repos);
        return;
    }

    // Default: list repos from cache (no age limit)
    let repos = load_repos_cache(u64::MAX).unwrap_or_default();
    let _ = serde_json::to_writer(std::io::stdout(), &repos);
}
