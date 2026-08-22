{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDev =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      portless = pkgs.stdenv.mkDerivation rec {
        pname = "portless";
        version = "0.15.5";

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
          sha256 = "0bix0jswg8na10vjziylmj744r86l5agkq15da1y1mlhsgwbfvzp";
        };

        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          mkdir -p $out/libexec/portless $out/bin
          cp -r * $out/libexec/portless/
          makeWrapper ${pkgs.nodejs}/bin/node $out/bin/portless \
            --add-flags "$out/libexec/portless/dist/cli.js"
        '';
      };
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
    in
    {

      environment.systemPackages = with pkgs; [
        devenv
        wrangler
        agent-browser
        portless
        herdr
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
