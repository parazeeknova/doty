use serde::Serialize;
use serde_json::Value;
use std::process::Command;

#[derive(Serialize)]
struct ClientInfo {
    address: String,
    title: String,
    workspace_id: i64,
    workspace_roman: String,
    class: String,
}

fn to_roman(mut num: i32) -> String {
    let mut roman = String::new();
    let values = [10, 9, 5, 4, 1];
    let symbols = ["X", "IX", "V", "IV", "I"];

    for i in 0..values.len() {
        while num >= values[i] {
            roman.push_str(symbols[i]);
            num -= values[i];
        }
    }
    roman
}

fn main() {
    let mut clients_list = Vec::new();
    let clients_out = Command::new("hyprctl").args(["clients", "-j"]).output();

    if let Ok(out) = clients_out
        && out.status.success()
    {
        let stdout_str = String::from_utf8_lossy(&out.stdout);
        if let Ok(Value::Array(clients)) = serde_json::from_str::<Value>(&stdout_str) {
            for client in clients {
                if let Some(title) = client.get("title").and_then(|t| t.as_str())
                    && !title.is_empty()
                    && let Some(ws_id) = client
                        .get("workspace")
                        .and_then(|w| w.get("id"))
                        .and_then(|id| id.as_i64())
                {
                    let address = client.get("address").and_then(|a| a.as_str()).unwrap_or_default().to_string();
                    let class = client.get("class").and_then(|c| c.as_str()).unwrap_or_default().to_string();
                    clients_list.push(ClientInfo {
                        address,
                        title: title.to_string(),
                        workspace_id: ws_id,
                        workspace_roman: to_roman(ws_id as i32),
                        class,
                    });
                }
            }
        }
    }

    #[derive(Serialize)]
    struct Response {
        clients: Vec<ClientInfo>,
    }

    let _ = serde_json::to_writer(std::io::stdout(), &Response { clients: clients_list });
}
