<div align="center">

  <a href="https://github.com/parazeeknova/doty">
    <img src="https://cdn.przknv.cc/doty/doty-banner.png" alt="homescreen" width="99%">
  </a>

</div>

<br />

<a id="what"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=686c5b&vCenter=true&width=435&height=25&lines=WHAT?" width="450"/>

Doty is a highly opinionated, fully [declarative](https://nix.dev/manual/nix/2.28/), and reproducible [NixOS](https://nixos.org/manual/nixos/stable/#preface) - [Hyprland](https://wiki.hypr.land) configuration that provides a complete desktop environment with pre-configured applications, services, and workflows. It is designed to be easy to install and maintain, while also being flexible enough to allow for customization and extension. I use it on my personal machine and it is tailored to my workflow, but it can be adapted to suit other users' needs as well. It is a work in progress and I am constantly improving it.

It has custom daemons [wabi](https://github.com/parazeeknova/doty/tree/main/wabi), keys, [widgets](https://github.com/parazeeknova/doty/tree/main/modules/features/wm/quickshell), launchers and services out-of-the-box. It is designed to be efficient and lightweight, while also providing a modern and visually appealing desktop environment. It is also designed to be modular and extensible, allowing users to easily add or remove components as needed all done in qml & rust.

This repository supports two setups depending on the branch:
- **[NixOS Setup (main branch)](https://github.com/parazeeknova/doty/tree/main)** (Current): A fully declarative system-level and user-level configuration powered by Nix flakes, NixOS modules, and Home Manager.
This contains latest changes as i've moved to NixOS.

- **[Arch Linux Setup (arch-dots branch)](https://github.com/parazeeknova/doty/tree/arch-dots)** (Legacy): A GNU Stow-based, distro-agnostic configuration tailored for Arch-based distributions.

<br />

<a id="features"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=686c5b&vCenter=true&width=435&height=25&lines=FEATURES" width="450"/>

- ❄️ **Declarative & Reproducible**: Powered by Nix Flakes and Home Manager to ensure your environment is fully reproducible across installations.
- 📦 **Everything Configured**: Fully customized daemons, keys, widgets, popups, launchers and services out-of-the-box, nix magic. *Yo arch so fat, when she tried to clone this, AUR servers went straight into swap memory.*
- 🧠 **AI-Powered (Local) Workflows**: Out-of-the-box integrations for local OCR, Speech-to-Text (STT), and LLMs.
- 🖼️ **Animated Wallpaper**: Automatically change your wallpaper based on time of day or system events or put an video.
- 🕛 **Screen Time & Focus Mode**: Track your screen time and enable focus mode to block distractions.
- 🤖 **Virtualization Maxx**: Waydroid, Droidbox(ubuntu, fedora, etc), VMware, Qemu/Libvirt all preconfigured for development.
- 🎨 **Matugen Dynamic Theming**: Colors dynamically generated from your active wallpaper to keep your workspace fresh and cohesive.
- 📜 **Horizontal Scrolling Layout**: Slide through workspace layers in a smooth horizontal layout.
- 🍸 **Liquid Glass Aesthetics**: Modern, translucent, and blurred glassmorphism so clean you'll try to wipe your greasy fingerprints off the screen.
- 🗣️ **Highly Opinionated**: Built with a curated layout and toolchain designed for efficiency for developers.
- ⚡ **Quickshell Popups**: Instant control panels, system sliders, and toggles right at your fingertips.
- ⚙️ **Under the Hood Nix Magic**: Lockfiles ensuring package version consistency across updates.
- 🍃 **Resource Efficient**: Tailored to run light on system resources.
- 🧩 **Modular & Extensible**: Easily add or remove components to suit your workflow.
- 🖥️ **Cockpit Integration**: Seamless integration with Cockpit for system management & instant logs.
- very more..

<br />

<a id="installation"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=686c5b&vCenter=true&width=435&height=25&lines=INSTALLATION" width="450"/>

The installation script is designed for a minimal [NixOS](https://nixos.org/manual/nixos/stable/#preface) install with a single user. It will automatically set up the system and user configurations, including all necessary packages, services, and settings, the old Arch Linux setup is still available in the [arch-dots branch](https://github.com/parazeeknova/doty/tree/arch-dots) but the support for it has been discontinued.

>[!IMPORTANT]
> This is a highly opinionated setup, and it is recommended to use it on a fresh NixOS installation & is very big and will take a lot of time to install, so please be patient. It is not recommended to use this on a production machine or a machine with important data. Also before running make sure to check your device related configuration.

To install, execute the following commands:

```shell
git clone --depth 1 https://github.com/parazeeknova/doty
cd ~/doty
sudo nixos-rebuild switch --flake .#apostrophe
```

>[!TIP]
> After one time installation, there is a handy alias `doty` to update the system and user configuration with a single command. Just run `doty` in the terminal.

<br />

<a id="updates"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=686c5b&vCenter=true&width=435&height=25&lines=UPDATES" width="450"/>

I frequently update the configuration with new features, bug fixes, and improvements. To update your installation, simply run the following command:

```shell
cd ~/doty
git pull
doty # Assuming you have the alias set up, otherwise run `sudo nixos-rebuild switch --flake .#apostrophe`
```

<br />

<a id="preview"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=686c5b&vCenter=true&width=435&height=25&lines=PREVIEW" width="450"/>

![Preview](https://cdn.przknv.cc/doty/anime.png)

| | | | |
| :---: | :---: | :---: | :---: |
| ![Preview 1](https://cdn.przknv.cc/doty/app-launcher.png) | ![Preview 2](https://cdn.przknv.cc/doty/battery.png) | ![Preview 3](https://cdn.przknv.cc/doty/brightness.png) | ![Preview 4](https://cdn.przknv.cc/doty/emoji.png) |
| ![Preview 5](https://cdn.przknv.cc/doty/github.png) | ![Preview 6](https://cdn.przknv.cc/doty/media.png) | ![Preview 7](https://cdn.przknv.cc/doty/podman.png) | ![Preview 8](https://cdn.przknv.cc/doty/clipboard.png) |
| ![Preview 9](https://cdn.przknv.cc/doty/system.png) | ![Preview 10](https://cdn.przknv.cc/doty/virtual.png) | ![Preview 11](https://cdn.przknv.cc/doty/wifi.png) | ![Preview 12](https://cdn.przknv.cc/doty/waydroid.png) |
| ![Preview 13](https://cdn.przknv.cc/doty/wallpaper-switcher.png) | ![Preview 14](https://cdn.przknv.cc/doty/control-center.png) | ![Preview 15](https://cdn.przknv.cc/doty/color-scheme.png) | ![Preview 16](https://cdn.przknv.cc/doty/screencapture.png) |

<br />

<a id="themes"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=686c5b&vCenter=true&width=435&height=25&lines=THEMES" width="450"/>

| | | | |
| :---: | :---: | :---: | :---: |
| ![Preview 17](https://cdn.przknv.cc/doty/t1.png) | ![Preview 18](https://cdn.przknv.cc/doty/t2.png) | ![Preview 19](https://cdn.przknv.cc/doty/t3.png) | ![Preview 20](https://cdn.przknv.cc/doty/t4.png) |

All application adopt the color scheme based on the current wallpaper. Here are some previews of different wallpapers and their corresponding dynamic themes.

<br />

<a id="credits"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=686c5b&vCenter=true&width=435&height=25&lines=CREDITS" width="450"/>

- **[NixOS](https://nixos.org/) & [Nix](https://nixos.org/manual/nix/stable/)** - The foundation of this system, providing a purely functional, declarative package management system & nice docs for [cuda](https://wiki.nixos.org/wiki/CUDA), [nvidia](https://wiki.nixos.org/wiki/NVIDIA), [qemu](https://wiki.nixos.org/wiki/QEMU) & etc.
- **[Hyprland](https://hyprland.org/)** - A highly customizable, dynamic tiling Wayland compositor with fluid animations.
- **[Quickshell](https://github.com/outfoxxed/quickshell)** - Framework used to build the responsive, QML-based desktop shell widgets and popups.
- **[Matugen](https://github.com/InioAsano/matugen)** - The color generation tool that dynamically extracts Material You themes from wallpapers.
- **[Waydroid](https://github.com/pioner14/Waydroid_on_NixOS)** - Waydroid configuration for nixOS on Hyprland.
- **[HyDE Project](https://github.com/hyde-project/hyde)** - Very good project for Hyprland configuration and scripts.
- **[Zen-Wabi](https://github.com/parazeeknova/zen-wabi)** - Matugen-driven dynamic theme for Zen Browser wallpaper-aware, per-site, hot-reloadable themes.
- And many other open-source projects and libraries that make this configuration like these possible.

<br />

This project is licensed under the MIT & Do whatever the fu* you want license. 