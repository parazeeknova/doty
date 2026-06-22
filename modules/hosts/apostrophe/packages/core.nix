{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesCore = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- Editors --
      vim
      neovim

      # -- Version Control --
      git
      lazygit

      # -- System Info --
      pciutils
      lshw
      inxi
      htop
      btop
      fastfetch

      # -- File Managers --
      yazi
      ranger
      thunar

      # -- Archives --
      unzip
      p7zip
      unrar
      gnutar
      gzip

      # -- Networking --
      wget
      curl
      openssh
      nettools
      nmap
      dig

      # -- Media --
      ffmpeg
      mpv
      imv
      pavucontrol

      # -- Fonts --
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      jetbrains-mono
      fira-code
      cascadia-code
    ];
  };
}
