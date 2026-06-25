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
        proton-vpn
        ani-cli
        mangal
        suwayomi-server
        cmatrix
        cowsay
        pokemon-colorscripts
        tty-clock
        fortune

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
        xclip

        # -- System Utils --
        htop
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
        tmux
        screen
        less
        man-db
        tldr
        direnv
        nix-direnv
      ];
    };
}
