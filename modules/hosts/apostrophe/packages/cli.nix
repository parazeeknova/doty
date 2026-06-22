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

      # -- Text Processing --
      jq
      yq
      gnused
      gawk
      gnugrep

      # -- System Utils --
      htop
      btop
      iotop
      powertop
      inxi
      lshw
      fastfetch
      neofetch

      # -- Network Utils --
      nmap
      netcat-openbsd
      socat
      dnsutils
      iperf3

      # -- Dev Tools --
      lazygit
      gitkraken

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
