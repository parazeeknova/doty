use rusqlite::Connection;
use serde::Serialize;
use std::collections::HashMap;
use std::env;
use wabi::print_json;

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
    ) {
        if let Ok(rows) = stmt.query_map([start, end], |row| {
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

    let db_path = wabi::quickshell_dir().join("screentime.db");
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
    ) {
        if let Ok(rows) = stmt.query_map([day_start, day_end], |row| {
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

    top_apps.sort_by(|a, b| b.seconds.cmp(&a.seconds));

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
