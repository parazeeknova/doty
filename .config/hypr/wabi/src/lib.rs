pub mod battery;
pub mod command;
pub mod external;
pub mod media_db;
pub mod paths;
pub mod settings;
pub mod state_file;

pub use battery::{BatterySnapshot, battery_snapshot, find_battery_dir};
pub use command::{run_cmd, run_cmd_with_stderr};
pub use external::{
    active_wifi_device, brightnessctl_percent, cidr_to_netmask, find_kbd_backlight_device,
    parse_percent, split_nmcli_t_line, wpctl_get_volume,
};
pub use paths::{cache_dir, dotfiles_dir, home_dir, quickshell_dir};
pub use settings::{load_json_with_default, save_json_atomic};
pub use state_file::{atomic_write_json, print_json, read_json, read_trimmed};

pub fn round_to(value: f64, places: f64) -> f64 {
    (value * places).round() / places
}
