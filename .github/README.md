<div align="center">

  <h2>wabi</h2>
  <h3>stowed in ~, worn with time</h3>
  <br>
  <a href="https://github.com/parazeeknova/doty">
    <img src="assets/1.png" alt="homescreen" width="99%">
  </a>

</div>

### doty
Daily driver configurations, custom desktop widgets, and companion daemons.

This repository supports two setups depending on the branch:
- **[NixOS Setup (main branch)](https://github.com/parazeeknova/doty/tree/main)** (Current): A fully declarative system-level and user-level configuration powered by Nix flakes, NixOS modules, and Home Manager.
- **[Arch Linux Setup (arch-dots branch)](https://github.com/parazeeknova/doty/tree/arch-dots)** (Legacy): A GNU Stow-based, distro-agnostic configuration tailored for Arch-based distributions.

#### what's inside

- **quickshell** - Custom interactive desktop widgets (including dashboard, popups, volume/brightness OSD, and notification overlays) written in Qt/QML and Javascript.
- **rust daemons** - Lightweight companion background services and utilities written in Rust (located under `wabi/`) to drive widgets, clipboard decoding, and system rebuild tasks efficiently.
- **configs & modules** - Declarative setup declarations (on `main`) or dotfiles (on `arch-dots`) covering:
  - **Window Manager**: Hyprland, Waybar, Mako (notifications), Cava (audio visualizer).
  - **Shell & Terminal**: Fish shell (fully configured), Starship prompt, Kitty & Ghostty terminals.
  - **Applications**: Zen Browser, Vesktop (Discord client), Spicetify (Spotify theming), and Zathura (document viewer).
  - **Theming**: Dynamic color generation and unified styling using GTK, Qt, Kvantum, and Matugen.


<div align="center">

###### *<div align="center"><sub>Gruvbox Rice</sub></div>*
  <a href="https://github.com/parazeeknova/doty">
    <img src="assets/rice.png" alt="rice" width="99%">
  </a>

  <br>

###### *<div align="center"><sub>Quickshell Utilities</sub></div>*
  <a href="https://github.com/parazeeknova/doty">
    <img src="assets/quickshell.png" alt="quickshell" width="99%">
  </a>
</div>

### What the hek is this ?
personal dotfiles. quickshell widgets, rust daemons, and configs i use daily.
nothing novel, just the way i like things..

### Would it work on my system ?
I use it daily on cachyos (i use arch btw). should work on any systemd-based distro with the right packages. package manager integrations are arch-only, everything else  
is portable.

### How to use ?
Just clone the repo in your home directory & use stow to symlink the files to their respective locations, then pray.

## notes
- some modules have hard dependencies, check the relevant config before enabling
- no install script, no hand-holding, stow and sort it yourself
- issues and PRs welcome if something's broken or you have suggestions