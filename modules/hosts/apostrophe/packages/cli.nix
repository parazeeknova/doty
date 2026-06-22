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
      fishPlugins.hydro
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

      # -- Text Processing --
      jq
      yq
      sed
      awk
      grep
      ripgrep

      # -- System Utils --
      htop
      btop
      iotop
      powertop
      lm_sensors
      usbutils
      pciutils
      lshw
      inxi

      # -- Network Utils --
      nmap
      netcat-openbsd
      socat
      dnsutils
      iperf3

      # -- Misc --
      tmux
      screen
      less
      man-db
      tldr
      cmatrix
      sl
      fortune
      cowsay
    ];
  };
}
