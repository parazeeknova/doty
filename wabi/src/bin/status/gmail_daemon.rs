use native_tls::TlsConnector;
use notify_rust::Notification;
use serde::Deserialize;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::Duration;

#[derive(Deserialize, Debug, Clone)]
struct Account {
    email: String,
    password: String,
}

fn main() {
    // 1. Load configuration file
    let config_path = get_config_path();
    println!("Loading configuration from {:?}", config_path);

    let accounts = match load_config(&config_path) {
        Ok(accs) => accs,
        Err(e) => {
            eprintln!("Error loading configuration: {}", e);
            std::process::exit(1);
        }
    };

    if accounts.is_empty() {
        eprintln!("No accounts configured. Exiting.");
        std::process::exit(0);
    }

    println!("Starting gmail_daemon for {} accounts", accounts.len());

    // 2. Spawn a thread for each account
    let mut handles = vec![];
    for account in accounts {
        let handle = thread::spawn(move || {
            run_account_loop(account);
        });
        handles.push(handle);
    }

    // Keep the main thread alive
    for handle in handles {
        let _ = handle.join();
    }
}

fn get_config_path() -> PathBuf {
    // Check command line arguments first: --config <path>
    let args: Vec<String> = env::args().collect();
    for i in 0..args.len() {
        if (args[i] == "--config" || args[i] == "-c") && i + 1 < args.len() {
            return PathBuf::from(&args[i + 1]);
        }
    }

    // Check environment variable
    if let Ok(env_path) = env::var("GMAIL_ACCOUNTS_JSON") {
        return PathBuf::from(env_path);
    }

    // Default to /run/secrets/gmail-accounts.json (Option C - SOPS/agenix)
    let sops_path = PathBuf::from("/run/secrets/gmail-accounts.json");
    if sops_path.exists() {
        return sops_path;
    }

    // Fallback to local test config
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    Path::new(&home).join(".config/wabi/gmail.json")
}

fn load_config(path: &Path) -> Result<Vec<Account>, Box<dyn std::error::Error>> {
    let content = fs::read_to_string(path)?;
    let accounts: Vec<Account> = serde_json::from_str(&content)?;
    Ok(accounts)
}

fn run_account_loop(account: Account) {
    let mut backoff = Duration::from_secs(5);
    let max_backoff = Duration::from_secs(300);

    loop {
        println!("[{}] Connecting to Gmail IMAP...", account.email);
        match connect_and_monitor(&account) {
            Ok(_) => {
                // If it returns Ok, it means we exited cleanly or connection closed cleanly.
                // Reset backoff.
                backoff = Duration::from_secs(5);
            }
            Err(e) => {
                eprintln!(
                    "[{}] Connection error: {}. Retrying in {:?}",
                    account.email, e, backoff
                );
                thread::sleep(backoff);
                backoff = std::cmp::min(backoff * 2, max_backoff);
            }
        }
    }
}

fn connect_and_monitor(account: &Account) -> Result<(), Box<dyn std::error::Error>> {
    let ssl_connector = TlsConnector::builder().build()?;
    let client = imap::connect(("imap.gmail.com", 993), "imap.gmail.com", &ssl_connector)?;

    let mut session = client
        .login(&account.email, &account.password)
        .map_err(|e| format!("Login failed: {:?}", e))?;

    // Select INBOX to receive events for it
    session.select("INBOX")?;
    println!("[{}] Connected and idling...", account.email);

    // Initial check: if there are already messages, we don't necessarily want to spam notifications.
    // We only send notifications for messages that arrive *while* the daemon is running.
    // So we record the last known message count.
    let mut last_message_count = get_message_count(&mut session)?;

    loop {
        // Start IDLE
        let idle = session.idle()?;

        // Wait until server pushes an update or connection times out / drops.
        // wait_keepalive blocks and automatically issues new IDLE commands
        // every 29 minutes to prevent inactivity timeout.
        let result = idle.wait_keepalive();

        // Parse result. If it's an error, propagate it (which will trigger reconnect)
        let _ = result?;

        // Recheck INBOX
        let count = get_message_count(&mut session)?;
        if count > last_message_count {
            // New message(s) arrived!
            for seq in (last_message_count + 1)..=count {
                if let Err(e) = handle_new_message(&mut session, seq, &account.email) {
                    eprintln!("[{}] Error fetching message info: {:?}", account.email, e);
                }
            }
        }
        last_message_count = count;
    }
}

fn get_message_count<T: std::io::Read + std::io::Write>(
    session: &mut imap::Session<T>,
) -> Result<u32, Box<dyn std::error::Error>> {
    let status = session.select("INBOX")?;
    Ok(status.exists)
}

fn handle_new_message<T: std::io::Read + std::io::Write>(
    session: &mut imap::Session<T>,
    seq: u32,
    email: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    // Fetch the Envelope
    let fetch_query = "ENVELOPE";
    let fetches = session.fetch(seq.to_string(), fetch_query)?;
    let msg = fetches.iter().next().ok_or("No fetch result returned")?;

    // Extract envelope details
    let envelope = msg.envelope().ok_or("Failed to get envelope")?;

    let subject = envelope
        .subject
        .as_ref()
        .map(|s| String::from_utf8_lossy(s).into_owned())
        .unwrap_or_else(|| "(No Subject)".to_string());

    let from = envelope
        .from
        .as_ref()
        .and_then(|f| f.first())
        .map(|addr| {
            let name = addr
                .name
                .as_ref()
                .map(|n| String::from_utf8_lossy(n).into_owned());
            let mailbox = addr
                .mailbox
                .as_ref()
                .map(|m| String::from_utf8_lossy(m).into_owned())
                .unwrap_or_default();
            let host = addr
                .host
                .as_ref()
                .map(|h| String::from_utf8_lossy(h).into_owned())
                .unwrap_or_default();
            let email_addr = format!("{}@{}", mailbox, host);
            match name {
                Some(n) if !n.trim().is_empty() => format!("{} <{}>", n, email_addr),
                _ => email_addr,
            }
        })
        .unwrap_or_else(|| "Unknown Sender".to_string());

    // Extract Message-ID header from envelope
    let message_id = envelope
        .message_id
        .as_ref()
        .map(|bytes| String::from_utf8_lossy(bytes).into_owned());

    // Construct click redirect URL using standard rfc822msgid search operator
    let url = if let Some(id) = message_id {
        // Strip angle brackets `<` and `>` if present
        let clean_id = id.trim_matches(|c| c == '<' || c == '>');
        // URL encode the message ID
        let encoded_id: String = clean_id
            .chars()
            .map(|c| match c {
                ':' => "%3A".to_string(),
                '@' => "%40".to_string(),
                '/' => "%2F".to_string(),
                '?' => "%3F".to_string(),
                '=' => "%3D".to_string(),
                '+' => "%2B".to_string(),
                ' ' => "%20".to_string(),
                _ => c.to_string(),
            })
            .collect();
        format!(
            "https://mail.google.com/mail/u/{}/#search/rfc822msgid%3A{}",
            email, encoded_id
        )
    } else {
        format!("https://mail.google.com/mail/u/{}/#inbox", email)
    };

    println!("[{}] New Email: {} - Subject: {}", email, from, subject);

    // Trigger Notification asynchronously so we don't block the IMAP connection loop
    let from_clone = from.clone();
    let subject_clone = subject.clone();
    let email_clone = email.to_string();
    thread::spawn(move || {
        send_notification(&email_clone, &from_clone, &subject_clone, &url);
    });

    Ok(())
}

fn send_notification(account_email: &str, from: &str, subject: &str, url: &str) {
    let mut notif = Notification::new();
    notif
        .summary(&format!("Gmail ({})", account_email))
        .body(&format!(
            "<b>From:</b> {}\n<b>Subject:</b> {}",
            from, subject
        ))
        .action("default", "Open in Browser")
        .hint(notify_rust::Hint::Category("email".to_string()))
        .hint(notify_rust::Hint::Urgency(notify_rust::Urgency::Normal))
        .timeout(notify_rust::Timeout::Never);

    match notif.show() {
        Ok(handle) => {
            let url_clone = url.to_string();
            // Block this spawned thread waiting for user action (click)
            handle.wait_for_action(move |action| {
                if action == "default" {
                    println!("Notification clicked! Opening URL: {}", url_clone);
                    let _ = std::process::Command::new("xdg-open")
                        .arg(&url_clone)
                        .status();
                }
            });
        }
        Err(e) => {
            eprintln!("Failed to show notification: {:?}", e);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn test_url_generation_with_id() {
        let email = "testuser@gmail.com";
        let message_id = Some("<abc123xyz@mail.gmail.com>".to_string());

        let url = if let Some(id) = message_id {
            let clean_id = id.trim_matches(|c| c == '<' || c == '>');
            let encoded_id: String = clean_id
                .chars()
                .map(|c| match c {
                    ':' => "%3A".to_string(),
                    '@' => "%40".to_string(),
                    '/' => "%2F".to_string(),
                    '?' => "%3F".to_string(),
                    '=' => "%3D".to_string(),
                    '+' => "%2B".to_string(),
                    ' ' => "%20".to_string(),
                    _ => c.to_string(),
                })
                .collect();
            format!(
                "https://mail.google.com/mail/u/{}/#search/rfc822msgid%3A{}",
                email, encoded_id
            )
        } else {
            format!("https://mail.google.com/mail/u/{}/#inbox", email)
        };

        assert_eq!(
            url,
            "https://mail.google.com/mail/u/testuser@gmail.com/#search/rfc822msgid%3Aabc123xyz%40mail.gmail.com"
        );
    }

    #[test]
    fn test_url_generation_no_id() {
        let email = "testuser@gmail.com";
        let message_id: Option<String> = None;

        let url = if let Some(id) = message_id {
            let clean_id = id.trim_matches(|c| c == '<' || c == '>');
            let encoded_id: String = clean_id
                .chars()
                .map(|c| match c {
                    ':' => "%3A".to_string(),
                    '@' => "%40".to_string(),
                    _ => c.to_string(),
                })
                .collect();
            format!(
                "https://mail.google.com/mail/u/{}/#search/rfc822msgid%3A{}",
                email, encoded_id
            )
        } else {
            format!("https://mail.google.com/mail/u/{}/#inbox", email)
        };

        assert_eq!(
            url,
            "https://mail.google.com/mail/u/testuser@gmail.com/#inbox"
        );
    }

    #[test]
    fn test_load_config() {
        let mut tmp_file = NamedTempFile::new().unwrap();
        let config_json = r#"[
            {"email": "one@gmail.com", "password": "pass1"},
            {"email": "two@gmail.com", "password": "pass2"}
        ]"#;
        tmp_file.write_all(config_json.as_bytes()).unwrap();

        let accounts = load_config(tmp_file.path()).unwrap();
        assert_eq!(accounts.len(), 2);
        assert_eq!(accounts[0].email, "one@gmail.com");
        assert_eq!(accounts[0].password, "pass1");
        assert_eq!(accounts[1].email, "two@gmail.com");
        assert_eq!(accounts[1].password, "pass2");
    }
}
