{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesCli = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- Shell Tools --
      starship
      zoxide
      fish
      bash
      fishPlugins.fzf
      fishPlugins.done
      fishPlugins.puffer
      fishPlugins.sponge
      fishPlugins.autopair

      # -- File Utils --
      ripgrep
      fd
      bat
      eza
      fzf
      tree
      file
      which
      tree-sitter
      yazi

      # -- Text Processing --
      jq
      yq
      gnused
      gawk
      gnugrep
      file
      xclip

      # -- System Utils --
      htop
      btop
      iotop
      powertop
      inxi
      lshw
      fastfetch
      killall
      pciutils
      usbutils

      # -- Network Utils --
      nmap
      netcat-openbsd
      socat
      dnsutils
      iperf3
      curl
      wget

      # -- Archive Utils --
      unzip
      p7zip
      unrar
      gnutar
      gzip

      # -- Dev Tools --
      lazygit
      gitkraken
      difftastic
      diff-so-fancy

      # -- Misc --
      tmux
      screen
      less
      man-db
      tldr
      direnv
      nix-direnv
      cmatrix
      sl
      fortune
      cowsay
    ];
  };
}
