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

      # -- Media --
      ffmpeg
      mpv
      pavucontrol
    ];
  };
}
