{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDev =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      environment.systemPackages = with pkgs; [
        devenv
        cudatoolkit
        wrangler
        google-cloud-sdk
        awscli
        cloudflare-cli
        appimage-run
        azure-cli
        terraform

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
        vscode-fhs
        vscode-insiders
        code-cursor-fhs
        zed-editor-fhs
        ghostty
        kitty
        act
        actionlint
        inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
        inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
        warp-terminal

        # -- Dev Tools --
        jupyter
        github-cli
        lazygit
        gitkraken
        difftastic
        diff-so-fancy
        beekeeper-studio
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
