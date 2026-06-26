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

        # -- Languages --
        nodejs
        python3
        rustup
        openjdk
        go

        # -- Package Managers --
        uv
        pnpm
        bun
        yarn
        biome
        turbo
        lefthook

        # -- Build Tools --
        gcc
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

        # -- Kubernetes --
        kubectl
        kubernetes-helm
        k9s
        kubectx
        stern
        minikube

        # -- Tools --
        mission-center
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
