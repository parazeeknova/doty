{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDesktop = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- General --
      vivaldi
      vscode
      kitty

      # -- Hyprland --
      waybar
      wofi
      swaylock
      swayidle
      grim
      slurp
      wl-clipboard
      cliphist
      mako
      hyprshot
      hyprpicker

      # -- Qt / GTK Themes --
      qt6ct
      qt5ct
      kvantum
      papirus-icon-theme
      papirus-folders
      capitaine-cursors

      # -- Fonts --
      noto-fonts
      noto-fonts-emoji
      nerd-fonts.fira-code
      nerd-fonts.noto
      nerd-fonts.hack
      nerd-fonts.iosevka
      nerd-fonts.victor-mono
    ];
  };
}
