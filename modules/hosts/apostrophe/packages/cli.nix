{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesCli =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      environment.systemPackages = with pkgs; [
        # -- JFR --
        cmatrix
        cowsay
        pokemon-colorscripts
        tty-clock
        fortune
        ani-cli

        # -- Editors --
        vim
        neovim

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
        stow

        # -- File Utils --
        ripgrep
        fd
        eza
        fzf
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

        # -- System Utils --
        iotop
        powertop
        inxi
        lshw
        fastfetch
        killall
        pciutils
        usbutils
        sbctl
        impala
        kexec-tools

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

        # -- Media --
        ffmpeg

        # -- Misc --
        less
        man-db
        tldr
        direnv
        nix-direnv
      ];
    };
}
