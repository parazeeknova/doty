use std::env;
use std::path::PathBuf;

pub fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

pub fn quickshell_dir() -> PathBuf {
    env::var_os("QUICKSHELL_DIR")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config/quickshell")))
        .unwrap_or_else(|| PathBuf::from(".config/quickshell"))
}

pub fn cache_dir() -> PathBuf {
    env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".cache"))
        .join("quickshell")
}

pub fn dotfiles_dir() -> PathBuf {
    env::var_os("WABI_DOTFILES_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join("doty"))
}
