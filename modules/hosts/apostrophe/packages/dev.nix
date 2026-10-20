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
        version = "0.9.5";

        src = pkgs.fetchurl {
          url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-x86_64";
          sha256 = "17cjb6gxh2wna8vv4bil82dz0qflfrpjcckwswc037jaifyfin8l";
        };

        dontUnpack = true;

        installPhase = ''
          install -m755 -D $src $out/bin/herdr
        '';
      };
      terminal-browser = pkgs.stdenv.mkDerivation rec {
        pname = "terminal-browser";
        version = "0.13.4";

        src = pkgs.fetchurl {
          url = "https://github.com/zenbu-labs/terminal-browser/releases/download/v${version}/terminal-browser-linux-x64.tar.gz";
          sha256 = "196k97b9cr68w9v50pf51bkwbylympzwsq8r7ymi2rxipamdlxv2";
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

          chmod +x $out/opt/terminal-browser/bin/terminal-browser
          find $out/opt/terminal-browser/electron -type f \( -name "electron" -o -name "pixel" \) -exec chmod +x {} +

          makeWrapper $out/opt/terminal-browser/bin/terminal-browser $out/bin/terminal-browser \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}"
        '';
      };
      terminal-code = pkgs.stdenv.mkDerivation rec {
        pname = "terminal-code";
        version = "0.4.3";

        src = pkgs.fetchurl {
          url = "https://github.com/zenbu-labs/terminal-code/releases/download/v${version}/tode-linux-x64.tar.gz";
          sha256 = "0l806jf3xhsw4wbaqnf42i9r264nlydz45j5p113ng5q3hr142rf";
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
            --set TODE_TERMINAL_BROWSER_BIN "${terminal-browser}/bin/terminal-browser" \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}"

          ln -s $out/bin/tode $out/bin/terminal-code
        '';
      };
      bun = pkgs.bun.overrideAttrs (oldAttrs: rec {
        pname = "bun";
        version = "1.4.3";
        src = pkgs.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
          sha256 = "063fh4iwnadqwx9g5wrp1afhkx2dgiw0cp7hhwzz0xcpv0l0awry";
        };
      });
      t3code = pkgs.appimageTools.wrapType2 rec {
        pname = "t3code";
        version = "0.1.1-nightly.20261020.3386";

        src = pkgs.fetchurl {
          url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
          sha256 = "19w29kmidpam5ig22kdmvlzr3njaiy1q408wg5z8pb5s7gzfzwbh";
        };

        extraPkgs =
          pkgs: with pkgs; [
            stdenv.cc.cc.lib
          ];

        extraInstallCommands =
          let
            extracted = pkgs.appimageTools.extract { inherit pname version src; };
          in
          ''
            mv $out/bin/t3code $out/bin/.t3code-unwrapped
            cat << 'WRAPPER' > $out/bin/t3code
            #!/usr/bin/env bash
            if [ -r /run/secrets/openrouter-api-key ]; then export OPENROUTER_API_KEY="$(cat /run/secrets/openrouter-api-key)"; fi
            if [ -r /run/secrets/context7-api-key ]; then export CONTEXT7_API_KEY="$(cat /run/secrets/context7-api-key)"; fi
            if [ -r /run/secrets/github-token ]; then export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat /run/secrets/github-token)"; fi
            if [ -r /run/secrets/tinyfish-api-key ]; then export TINYFISH_API_KEY="$(cat /run/secrets/tinyfish-api-key)"; fi
            if [ -r /run/secrets/merge-gateway-api-key ]; then export MERGE_GATEWAY_API_KEY="$(cat /run/secrets/merge-gateway-api-key)"; fi
            if [ -r /run/secrets/anthropic-api-key ]; then export ANTHROPIC_API_KEY="$(cat /run/secrets/anthropic-api-key)"; fi
            if [ -r /run/secrets/supermemory-codex-api-key ]; then
              export SUPERMEMORY_CODEX_API_KEY="$(cat /run/secrets/supermemory-codex-api-key)"
            elif [ -r /run/secrets/supermemory-api-key ]; then
              export SUPERMEMORY_CODEX_API_KEY="$(cat /run/secrets/supermemory-api-key)"
            fi
            if [ -r /run/secrets/supermemory-api-key ]; then
              export SUPERMEMORY_API_KEY="$(cat /run/secrets/supermemory-api-key)"
              export SUPERMEMORY_CC_API_KEY="$(cat /run/secrets/supermemory-api-key)"
            fi
            export SUPERMEMORY_BASE_URL="http://localhost:6767"
            export SUPERMEMORY_API_URL="http://localhost:6767"
            export STRIX_LLM="openai/deepseek/deepseek-v4-flash"
            export LLM_API_BASE="https://api-gateway.merge.dev/v1/openai"
            export OPENAI_BASE_URL="https://api-gateway.merge.dev/v1/openai"
            exec "$(dirname "$0")/.t3code-unwrapped" "$@"
            WRAPPER
            chmod +x $out/bin/t3code

            ln -s t3code $out/bin/t3code-desktop
            ln -s t3code $out/bin/t3

            mkdir -p $out/share/applications $out/share/icons
            cp -r ${extracted}/usr/share/icons $out/share/
            cp ${extracted}/t3code.desktop $out/share/applications/
            substituteInPlace $out/share/applications/t3code.desktop \
              --replace-fail "Exec=AppRun" "Exec=t3code"
          '';
      };
    in
    {

      environment.systemPackages = with pkgs; [
        devenv
        devin-cli
        wrangler
        agent-browser
        herdr
        terminal-browser
        terminal-code
        appimage-run
        cloudflare-cli
        awscli2
        google-cloud-sdk

        # -- Languages --
        nodejs
        typescript
        typescript-language-server
        python3
        rustup
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
        bubblewrap
        t3code

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
        opencode-desktop
        vscode-fhs
        vscode-insiders
        kitty
        act
        actionlint
        inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli

        # -- Dev Tools --
        github-cli
        lazygit
        gitkraken
        difftastic
        diff-so-fancy

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
