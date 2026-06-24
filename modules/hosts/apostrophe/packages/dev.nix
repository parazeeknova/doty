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
        go

        # -- Package Managers --
        pnpm
        bun
        yarn

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

        # -- Apps --
        opencode
        vscode
        ghostty
        kitty

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
