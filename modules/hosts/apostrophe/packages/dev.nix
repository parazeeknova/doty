{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDev =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      herdr = pkgs.stdenv.mkDerivation rec {
        pname = "herdr";
        version = "0.8.2";

        src = pkgs.fetchurl {
          url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-x86_64";
          sha256 = "1x7cda775xin16wjs63bwc97zdnzn9z1lbpa8fr983299nhm0qcp";
        };

        dontUnpack = true;

        installPhase = ''
          install -m755 -D $src $out/bin/herdr
        '';
      };
      terminal-browser = pkgs.stdenv.mkDerivation rec {
        pname = "terminal-browser";
        version = "0.6.0";

        src = pkgs.fetchurl {
          url = "https://github.com/zenbu-labs/terminal-browser/releases/download/v${version}/terminal-browser-linux-x64.tar.gz";
          sha256 = "1xwzq3vg05cj2nx5bjac7hcsdrpcmv799jjyc44j38936rcpa8vw";
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          makeWrapper
        ];

        buildInputs = with pkgs; [
          alsa-lib
          at-spi2-atk
          at-spi2-core
          atk
          cairo
          cups
          dbus
          expat
          gdk-pixbuf
          glib
          gtk3
          mesa
          nspr
          nss
          pango
          systemd
          libx11
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxrandr
          libxcb
          libxkbfile
          libxcursor
          libxi
          libxrender
          libxtst
          libxscrnsaver
          libxkbcommon
          libdrm
          libgbm
          vulkan-loader
          stdenv.cc.cc.lib
        ];

        sourceRoot = "terminal-browser";

        installPhase = ''
          mkdir -p $out/opt/terminal-browser $out/bin
          cp -r * $out/opt/terminal-browser/

          chmod +x $out/opt/terminal-browser/bin/terminal-browser $out/opt/terminal-browser/electron/electron

          makeWrapper $out/opt/terminal-browser/bin/terminal-browser $out/bin/terminal-browser \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}"
        '';
      };
      terminal-code = pkgs.stdenv.mkDerivation rec {
        pname = "terminal-code";
        version = "0.2.0";

        src = pkgs.fetchurl {
          url = "https://github.com/zenbu-labs/terminal-code/releases/download/v${version}/tode-linux-x64.tar.gz";
          sha256 = "1yrir153zrzn6zh30493i19zi6la01hx75wyl7v2mh1g5bymdsl3";
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          makeWrapper
        ];

        buildInputs = with pkgs; [
          alsa-lib
          at-spi2-atk
          at-spi2-core
          atk
          cairo
          cups
          dbus
          expat
          gdk-pixbuf
          glib
          gtk3
          mesa
          nspr
          nss
          pango
          systemd
          libx11
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxrandr
          libxcb
          libxkbfile
          libxcursor
          libxi
          libxrender
          libxtst
          libxscrnsaver
          libxkbcommon
          libdrm
          libgbm
          vulkan-loader
          stdenv.cc.cc.lib
        ];

        sourceRoot = "tode";

        installPhase = ''
          mkdir -p $out/opt/terminal-code $out/bin
          cp -r * $out/opt/terminal-code/

          find $out/opt/terminal-code -type f -name "electron" -exec chmod +x {} +
          chmod +x $out/opt/terminal-code/bin/tode 2>/dev/null || true

          makeWrapper $out/opt/terminal-code/bin/tode $out/bin/tode \
            --set TODE_INSTALL_ROOT "$out/opt/terminal-code" \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}"

          ln -s $out/bin/tode $out/bin/terminal-code
        '';
      };
    in
    {

      environment.systemPackages = with pkgs; [
        devenv
        wrangler
        agent-browser
        herdr
        terminal-browser
        terminal-code
        appimage-run
        azure-cli
        cloudflare-cli
        awscli2
        google-cloud-sdk

        # -- Languages --
        nodejs
        python3
        rustup
        openjdk
        temurin-bin
        temurin-jre-bin
        go
        zig
        zigimports
        zig-zlint

        # -- Package Managers --
        uv
        pnpm
        bun
        yarn
        biome
        turbo
        lefthook

        # -- Build Tools --
        (lib.lowPrio gcc)
        llvmPackages.clang
        clang-tools
        gnumake
        cmake
        pkg-config
        openssl

        # -- Nix --
        nix-output-monitor
        nixfmt
        nil
        cachix

        # -- Apps --
        opencode
        opencode-desktop
        vscode-fhs
        vscode-insiders
        code-cursor-fhs
        ghostty
        kitty
        act
        actionlint
        inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
        inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli

        # -- Dev Tools --
        jupyter
        github-cli
        lazygit
        gitkraken
        difftastic
        diff-so-fancy
        figma-linux
        figma-agent

        # -- Kubernetes --
        kubectl
        kubernetes-helm
        k9s
        kubectx
        stern
        minikube

        # -- Tools --
        httpie
        tmux
        tmuxPlugins.cpu
        tmuxPlugins.yank
        tmuxPlugins.battery
        tmuxPlugins.continuum
        tmuxPlugins.resurrect
        tmuxPlugins.catppuccin
        tmuxPlugins.sessionist
        tmuxPlugins.tmux-floax
        tmuxPlugins.online-status
        tmuxPlugins.tmux-sessionx
      ];
    };
}
