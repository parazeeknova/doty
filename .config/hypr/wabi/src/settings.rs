use std::io;
use std::path::Path;

use crate::state_file;

pub fn load_json_with_default<T: serde::de::DeserializeOwned + Default>(path: &Path) -> T {
    state_file::read_json(path).unwrap_or_default()
}

pub fn save_json_atomic<T: serde::Serialize>(path: &Path, value: &T) -> io::Result<()> {
    state_file::atomic_write_json(path, value)
}
