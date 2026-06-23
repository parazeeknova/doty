use rusqlite::Connection;
use serde::Serialize;
use std::collections::HashMap;
use std::env;
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::process::Command;
use wabi::print_json;

fn ipc_socket_path() -> String {
    let runtime_dir = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".to_string());
    format!("{}/wabi_screentime.sock", runtime_dir)
}

fn ensure_daemon_running() -> bool {
    let socket = ipc_socket_path();

    // Fast path: daemon is alive and responding
    if Path::new(&socket).exists() && UnixStream::connect(&socket).is_ok() {
        return true;
    }

    // Socket stale or missing — clean up and start fresh
    if Path::new(&socket).exists() {
        let _ = std::fs::remove_file(&socket);
    }

    eprintln!("Screentime daemon not running, starting...");
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let daemon_path = format!("{}/.local/bin/screentime_daemon", home);

    if let Err(e) = Command::new(&daemon_path)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn()
    {
        eprintln!("Failed to start screentime daemon: {}", e);
        return false;
    }

    // Wait for the daemon to initialize and bind its socket
    for _ in 0..10 {
        std::thread::sleep(std::time::Duration::from_millis(200));
        if Path::new(&socket).exists() && UnixStream::connect(&socket).is_ok() {
            return false;
        }
    }
    eprintln!("Screentime daemon still not ready after start.");
    false
}

#[derive(Serialize)]
struct TopAppItem {
    class: String,
    time: String,
    seconds: i64,
    percentage: i64,
}

#[derive(Serialize)]
struct ScreentimeResult {
    label: String,
    total_active_time: String,
    total_active_seconds: i64,
    idle_time: String,
    idle_seconds: i64,
    hourly_chart: Vec<i64>,
    top_apps: Vec<TopAppItem>,
    trend_label: String,
}

fn get_active_seconds(conn: &Connection, start: i64, end: i64) -> i64 {
    let mut sessions = Vec::new();
    if let Ok(mut stmt) = conn.prepare(
        "SELECT app_class, start_time, end_time FROM sessions
         WHERE end_time > ?1 AND start_time < ?2;",
    ) && let Ok(rows) = stmt.query_map([start, end], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, i64>(1)?,
            row.get::<_, i64>(2)?,
        ))
    }) {
        for row in rows.flatten() {
            sessions.push(row);
        }
    }

    let mut total = 0;
    for (class, start_time, end_time) in sessions {
        let overlap_start = std::cmp::max(start_time, start);
        let overlap_end = std::cmp::min(end_time, end);
        let duration = std::cmp::max(0, overlap_end - overlap_start);
        if duration > 0 && class.to_lowercase().trim() != "idle" && !class.trim().is_empty() {
            total += duration;
        }
    }
    total
}

struct SessionRecord {
    class: String,
    _title: String,
    start_time: i64,
    end_time: i64,
}

fn format_duration(seconds: i64) -> String {
    if seconds == 0 {
        return "0m".to_string();
    }
    let h = seconds / 3600;
    let m = (seconds % 3600) / 60;
    let s = seconds % 60;
    if h > 0 {
        if m > 0 {
            format!("{}h {}m", h, m)
        } else {
            format!("{}h", h)
        }
    } else if m > 0 {
        format!("{}m", m)
    } else {
        format!("{}s", s)
    }
}

fn main() {
    let offset: i32 = env::args()
        .nth(1)
        .and_then(|s| s.parse::<i32>().ok())
        .unwrap_or(0);

    // Ensure daemon is running before querying
    let was_already_running = ensure_daemon_running();

    // If daemon was just started, give it time to write the first session to DB
    if !was_already_running {
        std::thread::sleep(std::time::Duration::from_millis(500));
    }

    let db_path = wabi::quickshell_dir()
        .join("notif_popup")
        .join("screentime.db");
    let conn = match Connection::open(db_path) {
        Ok(c) => c,
        Err(_) => {
            // Output empty state if DB doesn't exist yet
            let result = ScreentimeResult {
                label: if offset == 0 {
                    "Today".to_string()
                } else if offset == -1 {
                    "Yesterday".to_string()
                } else {
                    "Unknown".to_string()
                },
                total_active_time: "0m".to_string(),
                total_active_seconds: 0,
                idle_time: "0m".to_string(),
                idle_seconds: 0,
                hourly_chart: vec![0; 24],
                top_apps: Vec::new(),
                trend_label: "".to_string(),
            };
            print_json(&result);
            return;
        }
    };

    let modifier = format!("{} days", offset);
    let day_start: i64 = conn
        .query_row(
            "SELECT unixepoch('now', 'localtime', 'start of day', ?, 'utc');",
            [&modifier],
            |row| row.get(0),
        )
        .unwrap_or(0);

    let day_end = day_start + 24 * 3600;

    let label: String = if offset == 0 {
        "Today".to_string()
    } else if offset == -1 {
        "Yesterday".to_string()
    } else {
        conn.query_row(
            "SELECT strftime('%Y-%m-%d', 'now', 'localtime', ?);",
            [&modifier],
            |row| row.get(0),
        )
        .unwrap_or_else(|_| "Unknown".to_string())
    };

    let mut sessions = Vec::new();
    if let Ok(mut stmt) = conn.prepare(
        "SELECT app_class, title, start_time, end_time FROM sessions
         WHERE end_time > ?1 AND start_time < ?2;",
    ) && let Ok(rows) = stmt.query_map([day_start, day_end], |row| {
        Ok(SessionRecord {
            class: row.get(0)?,
            _title: row.get(1)?,
            start_time: row.get(2)?,
            end_time: row.get(3)?,
        })
    }) {
        for row in rows.flatten() {
            sessions.push(row);
        }
    }

    let mut total_active_seconds = 0i64;
    let mut idle_seconds = 0i64;
    let mut hourly_chart = vec![0i64; 24];
    let mut app_seconds: HashMap<String, i64> = HashMap::new();

    for session in sessions {
        let overlap_start = std::cmp::max(session.start_time, day_start);
        let overlap_end = std::cmp::min(session.end_time, day_end);
        let duration = std::cmp::max(0, overlap_end - overlap_start);
        if duration == 0 {
            continue;
        }

        let normalized_class = session.class.to_lowercase().trim().to_string();
        if normalized_class == "idle" {
            idle_seconds += duration;
            continue;
        }

        total_active_seconds += duration;

        if !normalized_class.is_empty() {
            *app_seconds.entry(normalized_class).or_insert(0) += duration;
        }

        // Distribute duration into hourly bins
        for hour in 0..24 {
            let hour_start = day_start + hour * 3600;
            let hour_end = hour_start + 3600;
            let h_start = std::cmp::max(overlap_start, hour_start);
            let h_end = std::cmp::min(overlap_end, hour_end);
            let h_duration = std::cmp::max(0, h_end - h_start);
            if h_duration > 0 {
                hourly_chart[hour as usize] += h_duration;
            }
        }
    }

    let mut top_apps = Vec::new();
    for (class, seconds) in app_seconds {
        let percentage = if total_active_seconds > 0 {
            ((seconds as f64 / total_active_seconds as f64) * 100.0).round() as i64
        } else {
            0
        };
        top_apps.push(TopAppItem {
            class,
            time: format_duration(seconds),
            seconds,
            percentage,
        });
    }

    top_apps.sort_by_key(|b| std::cmp::Reverse(b.seconds));

    let prev_active_seconds = get_active_seconds(&conn, day_start - 24 * 3600, day_start);
    let trend_label = if prev_active_seconds == 0 {
        if total_active_seconds > 0 {
            "^ 100% from last day".to_string()
        } else {
            "flat".to_string()
        }
    } else {
        let diff = total_active_seconds - prev_active_seconds;
        let pct = ((diff as f64 / prev_active_seconds as f64) * 100.0).round() as i64;
        if pct > 0 {
            format!("^ {}% from last day", pct)
        } else if pct < 0 {
            format!("v {}% from last day", pct.abs())
        } else {
            "flat".to_string()
        }
    };

    let result = ScreentimeResult {
        label,
        total_active_time: format_duration(total_active_seconds),
        total_active_seconds,
        idle_time: format_duration(idle_seconds),
        idle_seconds,
        hourly_chart,
        top_apps,
        trend_label,
    };

    print_json(&result);
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::params;

    fn setup_test_db() -> Connection {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(
            "CREATE TABLE sessions (
                app_class TEXT NOT NULL,
                title TEXT NOT NULL,
                start_time INTEGER NOT NULL,
                end_time INTEGER NOT NULL,
                duration INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX idx_sessions_start ON sessions(start_time);
            CREATE INDEX idx_sessions_end ON sessions(end_time);",
        )
        .unwrap();
        conn
    }

    fn insert_session(conn: &Connection, class: &str, start: i64, end: i64) {
        conn.execute(
            "INSERT INTO sessions (app_class, title, start_time, end_time, duration) VALUES (?1, 'test', ?2, ?3, ?3 - ?2)",
            params![class, start, end],
        )
        .unwrap();
    }

    #[test]
    fn format_duration_outputs_correctly() {
        assert_eq!(format_duration(0), "0m");
        assert_eq!(format_duration(30), "30s");
        assert_eq!(format_duration(90), "1m");
        assert_eq!(format_duration(3600), "1h");
        assert_eq!(format_duration(3660), "1h 1m");
        assert_eq!(format_duration(7200), "2h");
        assert_eq!(format_duration(7260), "2h 1m");
    }

    #[test]
    fn overlap_math_session_fully_inside_window() {
        let conn = setup_test_db();
        // day_start=1000, day_end=1000+86400. Session is from 2000-5000.
        insert_session(&conn, "firefox", 2000, 5000);
        let active = get_active_seconds(&conn, 1000, 1000 + 86400);
        assert_eq!(active, 3000);
    }

    #[test]
    fn overlap_math_session_partially_before_window() {
        let conn = setup_test_db();
        // Session starts before window, ends inside it
        insert_session(&conn, "terminal", 500, 3000);
        let active = get_active_seconds(&conn, 1000, 1000 + 86400);
        assert_eq!(active, 2000); // only 2000-3000 overlaps
    }

    #[test]
    fn overlap_math_session_partially_after_window() {
        let conn = setup_test_db();
        // Session starts inside window, ends after it
        insert_session(&conn, "code", 86000, 87000);
        let active = get_active_seconds(&conn, 0, 86400);
        assert_eq!(active, 400); // only 86000-86400 overlaps
    }

    #[test]
    fn overlap_math_session_spanning_entire_window() {
        let conn = setup_test_db();
        // Session encloses the entire window
        insert_session(&conn, "browser", 0, 200000);
        let active = get_active_seconds(&conn, 10000, 96400);
        assert_eq!(active, 86400);
    }

    #[test]
    fn overlap_math_session_completely_outside_window() {
        let conn = setup_test_db();
        // Session is before the window
        insert_session(&conn, "editor", 100, 500);
        let active = get_active_seconds(&conn, 1000, 1000 + 86400);
        assert_eq!(active, 0);
    }

    #[test]
    fn overlap_math_idle_sessions_excluded() {
        let conn = setup_test_db();
        insert_session(&conn, "idle", 1000, 5000);
        insert_session(&conn, "firefox", 2000, 7000);
        let active = get_active_seconds(&conn, 0, 10000);
        assert_eq!(active, 5000); // idle excluded, only firefox counts
    }

    #[test]
    fn overlap_math_empty_class_excluded() {
        let conn = setup_test_db();
        insert_session(&conn, "", 1000, 5000);
        let active = get_active_seconds(&conn, 0, 10000);
        assert_eq!(active, 0);
    }

    #[test]
    fn overlap_math_multiple_sessions_sum_correctly() {
        let conn = setup_test_db();
        insert_session(&conn, "firefox", 1000, 3000);
        insert_session(&conn, "terminal", 4000, 7000);
        insert_session(&conn, "code", 6000, 8000);
        let active = get_active_seconds(&conn, 0, 10000);
        // firefox: 1000-3000 → 2000s, terminal: 4000-7000 → 3000s, code: 6000-8000 → 2000s
        assert_eq!(active, 7000);
    }

    #[test]
    fn hourly_chart_logic_distributes_correctly() {
        // Test the hourly distribution inline: a 2-hour session across hours 10-12
        let day_start: i64 = 0;
        let overlap_start: i64 = 10 * 3600;
        let overlap_end: i64 = 12 * 3600;
        let mut hourly = [0i64; 24];

        for hour in 0..24 {
            let hour_start = day_start + hour * 3600;
            let hour_end = hour_start + 3600;
            let h_start = std::cmp::max(overlap_start, hour_start);
            let h_end = std::cmp::min(overlap_end, hour_end);
            let h_duration = std::cmp::max(0, h_end - h_start);
            if h_duration > 0 {
                hourly[hour as usize] += h_duration;
            }
        }

        assert_eq!(hourly[9], 0);
        assert_eq!(hourly[10], 3600);
        assert_eq!(hourly[11], 3600);
        assert_eq!(hourly[12], 0);
    }

    #[test]
    fn hourly_chart_partial_hours_distributed_correctly() {
        // 10:30 to 11:45 = 1h 15m → hour 10 gets 1800s, hour 11 gets 2700s
        let day_start: i64 = 0;
        let overlap_start: i64 = 10 * 3600 + 1800; // 10:30
        let overlap_end: i64 = 11 * 3600 + 2700; // 11:45
        let mut hourly = [0i64; 24];

        for hour in 0..24 {
            let hour_start = day_start + hour * 3600;
            let hour_end = hour_start + 3600;
            let h_start = std::cmp::max(overlap_start, hour_start);
            let h_end = std::cmp::min(overlap_end, hour_end);
            let h_duration = std::cmp::max(0, h_end - h_start);
            if h_duration > 0 {
                hourly[hour as usize] += h_duration;
            }
        }

        assert_eq!(hourly[10], 1800);
        assert_eq!(hourly[11], 2700);
    }
}
