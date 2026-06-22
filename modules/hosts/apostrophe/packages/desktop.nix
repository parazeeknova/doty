{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDesktop = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- Browsers --
      firefox
      chromium

      # -- Editors (GUI) --
      vscode

      # -- Terminal Emulators --
      ghostty
      kitty

      # -- Wayland / Hyprland --
      waybar
      wofi
      swaylock
      swayidle
      grim
      slurp
      wl-clipboard
      cliphist
      mako
      dunst
      hyprshot
      hyprpicker

      # -- Qt / GTK --
      qt6ct
      qt5ct
      kvantum
      papirus-icon-theme
      capitaine-cursors

      # -- Media (GUI) --
      obs-studio
      gimp
      inkscape
      file-roller

      # -- Documents --
      zathura
      evince
      libreoffice

      # -- Communication --
      vesktop
      telegram-desktop
      signal-desktop
    ];
  };
}
