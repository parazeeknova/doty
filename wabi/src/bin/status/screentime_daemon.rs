use rusqlite::Connection;
use serde_json::Value;
use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::Path;
use std::process::Command;
use std::sync::mpsc::{Sender, channel};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

fn ipc_socket_path() -> String {
    let runtime_dir = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".to_string());
    format!("{}/wabi_screentime.sock", runtime_dir)
}

#[derive(Debug)]
struct ActiveWindow {
    class: String,
    title: String,
    _start_time: i64,
}

enum Message {
    Idle,
    Resume,
    HyprlandEvent(String),
}

fn get_now_seconds() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn db_conn() -> Result<Connection, rusqlite::Error> {
    let db_path = wabi::quickshell_dir().join("notif_popup").join("screentime.db");
    if let Some(parent) = db_path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let conn = Connection::open(db_path)?;
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_class TEXT NOT NULL,
            title TEXT NOT NULL,
            start_time INTEGER NOT NULL,
            end_time INTEGER NOT NULL,
            duration INTEGER NOT NULL
        );",
        [],
    )?;
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_sessions_start ON sessions(start_time);",
        [],
    )?;
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_sessions_class ON sessions(app_class);",
        [],
    )?;
    Ok(conn)
}

fn prune_old_sessions(conn: &Connection) -> Result<(), rusqlite::Error> {
    let thirty_days_ago = get_now_seconds() - (30 * 24 * 60 * 60);
    conn.execute(
        "DELETE FROM sessions WHERE start_time < ?;",
        [thirty_days_ago],
    )?;
    Ok(())
}

fn save_session(
    conn: &Connection,
    class: &str,
    title: &str,
    start_time: i64,
    end_time: i64,
) -> Result<i64, rusqlite::Error> {
    let duration = end_time - start_time;
    conn.execute(
        "INSERT INTO sessions (app_class, title, start_time, end_time, duration) VALUES (?, ?, ?, ?, ?);",
        (class, title, start_time, end_time, duration),
    )?;
    Ok(conn.last_insert_rowid())
}

fn update_session(conn: &Connection, id: i64, end_time: i64) -> Result<(), rusqlite::Error> {
    conn.execute(
        "UPDATE sessions SET end_time = ?, duration = ? - start_time WHERE id = ?;",
        (end_time, end_time, id),
    )?;
    Ok(())
}

fn query_current_active_window() -> Option<(String, String)> {
    let output = Command::new("hyprctl")
        .args(["activewindow", "-j"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let val: Value = serde_json::from_slice(&output.stdout).ok()?;
    let class = val.get("class")?.as_str()?.to_string();
    let title = val
        .get("title")
        .and_then(|t| t.as_str())
        .unwrap_or("")
        .to_string();
    if class.is_empty() {
        None
    } else {
        Some((class, title))
    }
}

fn start_hyprland_listener(tx: Sender<Message>) {
    thread::spawn(move || {
        loop {
            if let Ok(sig) = env::var("HYPRLAND_INSTANCE_SIGNATURE") {
                let runtime_dir =
                    env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/run/user/1000".to_string());
                let socket_path = format!("{}/hypr/{}/.socket2.sock", runtime_dir, sig);
                let socket_path = if Path::new(&socket_path).exists() {
                    socket_path
                } else {
                    format!("/tmp/hypr/{}/.socket2.sock", sig)
                };

                if Path::new(&socket_path).exists()
                    && let Ok(stream) = UnixStream::connect(&socket_path)
                {
                    let reader = BufReader::new(stream);
                    for line in reader.lines() {
                        if let Ok(l) = line {
                            if l.starts_with("activewindow>>") || l.starts_with("activewindowv2>>")
                            {
                                let _ = tx.send(Message::HyprlandEvent(l));
                            }
                        } else {
                            break;
                        }
                    }
                }
            }
            thread::sleep(Duration::from_secs(2));
        }
    });
}

fn start_ipc_listener(tx: Sender<Message>) {
    let socket_path = ipc_socket_path();
    let _ = fs::remove_file(&socket_path);
    let listener = UnixListener::bind(&socket_path).expect("Failed to bind IPC socket");
    thread::spawn(move || {
        for mut stream in listener.incoming().flatten() {
            let reader = BufReader::new(&stream);
            if let Some(Ok(line)) = reader.lines().next() {
                match line.trim() {
                    "idle" => {
                        let _ = tx.send(Message::Idle);
                        let _ = stream.write_all(b"ok\n");
                    }
                    "resume" => {
                        let _ = tx.send(Message::Resume);
                        let _ = stream.write_all(b"ok\n");
                    }
                    _ => {
                        let _ = stream.write_all(b"unknown command\n");
                    }
                }
            }
        }
    });
}

fn client_send(cmd: &str) {
    if let Ok(mut stream) = UnixStream::connect(ipc_socket_path()) {
        let _ = stream.write_all(format!("{}\n", cmd).as_bytes());
        let mut response = String::new();
        let mut reader = BufReader::new(stream);
        let _ = reader.read_line(&mut response);
        println!("Server response: {}", response.trim());
    } else {
        eprintln!("Failed to connect to daemon. Is it running?");
        std::process::exit(1);
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() > 1 {
        match args[1].as_str() {
            "--idle" => {
                client_send("idle");
                return;
            }
            "--resume" => {
                client_send("resume");
                return;
            }
            _ => {
                eprintln!("Usage: {} [--idle | --resume]", args[0]);
                std::process::exit(1);
            }
        }
    }

    // Check if another daemon instance is already running
    if UnixStream::connect(ipc_socket_path()).is_ok() {
        eprintln!("screentime_daemon is already running.");
        std::process::exit(1);
    }

    println!("Starting screentime_daemon...");
    let conn = db_conn().expect("Failed to initialize database");
    println!("Database initialized successfully.");
    let _ = prune_old_sessions(&conn);

    let (tx, rx) = channel::<Message>();

    println!("Starting Hyprland and IPC listeners...");
    start_hyprland_listener(tx.clone());
    start_ipc_listener(tx);

    let mut current_window: Option<ActiveWindow> = None;
    let mut current_session_id: Option<i64> = None;
    let mut is_idle = false;

    // Start tracking the initial window if possible
    println!("Querying initial active window...");
    if let Some((class, title)) = query_current_active_window() {
        println!("Initial window class: '{}', title: '{}'", class, title);
        let now = get_now_seconds();
        if !class.trim().is_empty() {
            current_window = Some(ActiveWindow {
                class: class.clone(),
                title: title.clone(),
                _start_time: now,
            });
            match save_session(&conn, &class, &title, now, now) {
                Ok(id) => {
                    println!("Saved initial session in DB with row id: {}", id);
                    current_session_id = Some(id);
                }
                Err(e) => {
                    eprintln!("Failed to save initial session: {:?}", e);
                }
            }
        }
    } else {
        println!("No active window found or hyprctl failed.");
    }

    println!("Entering main loop...");
    loop {
        // Recv events or tick every 5 seconds to update the current session in the database
        let msg = match rx.recv_timeout(Duration::from_secs(5)) {
            Ok(m) => Some(m),
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
                println!("Tick timeout received");
                None
            }
            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
                println!("Channel disconnected");
                break;
            }
        };

        let now = get_now_seconds();

        if let Some(m) = msg {
            match m {
                Message::Idle => {
                    if !is_idle {
                        is_idle = true;
                        if let Some(id) = current_session_id.take() {
                            let _ = update_session(&conn, id, now);
                        }
                        current_window = Some(ActiveWindow {
                            class: "idle".to_string(),
                            title: "Idle".to_string(),
                            _start_time: now,
                        });
                        if let Ok(id) = save_session(&conn, "idle", "Idle", now, now) {
                            current_session_id = Some(id);
                        }
                    }
                }
                Message::Resume => {
                    if is_idle {
                        is_idle = false;
                        if let Some(id) = current_session_id.take() {
                            let _ = update_session(&conn, id, now);
                        }
                        if let Some((class, title)) = query_current_active_window() {
                            if !class.trim().is_empty() {
                                current_window = Some(ActiveWindow {
                                    class: class.clone(),
                                    title: title.clone(),
                                    _start_time: now,
                                });
                                if let Ok(id) = save_session(&conn, &class, &title, now, now) {
                                    current_session_id = Some(id);
                                }
                            } else {
                                current_window = None;
                            }
                        } else {
                            current_window = None;
                        }
                    }
                }
                Message::HyprlandEvent(event_str) => {
                    let (class, title) = if event_str.starts_with("activewindowv2>>") {
                        let payload = event_str.trim_start_matches("activewindowv2>>");
                        let parts: Vec<&str> = payload.splitn(3, ',').collect();
                        if parts.len() >= 3 {
                            (parts[1].to_string(), parts[2].to_string())
                        } else {
                            continue;
                        }
                    } else if event_str.starts_with("activewindow>>") {
                        let payload = event_str.trim_start_matches("activewindow>>");
                        let parts: Vec<&str> = payload.splitn(2, ',').collect();
                        if parts.len() >= 2 {
                            (parts[0].to_string(), parts[1].to_string())
                        } else {
                            continue;
                        }
                    } else {
                        continue;
                    };

                    if is_idle {
                        continue;
                    }

                    let changed = match &current_window {
                        Some(curr) => curr.class != class || curr.title != title,
                        None => true,
                    };

                    if changed {
                        if let Some(id) = current_session_id.take() {
                            let _ = update_session(&conn, id, now);
                        }
                        if !class.trim().is_empty() {
                            current_window = Some(ActiveWindow {
                                class: class.clone(),
                                title: title.clone(),
                                _start_time: now,
                            });
                            if let Ok(id) = save_session(&conn, &class, &title, now, now) {
                                current_session_id = Some(id);
                            }
                        } else {
                            current_window = None;
                        }
                    }
                }
            }
        } else {
            // Periodic tick: update the duration of the current session in the DB
            if let Some(id) = current_session_id {
                let _ = update_session(&conn, id, now);
            }
        }
    }
}
