{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDev = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- Languages --
      nodejs
      python3
      rustup
      go

      # -- Dev Tools --
      git
      lazygit
      gitkraken
      difftastic
      diff-so-fancy

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
      nixfmt-rfc-style
      nil

      # -- API Tools --
      httpie

      # -- Misc --
      ripgrep
      fd
      bat
      eza
      fzf
      zoxide
      tree-sitter
      direnv
      nix-direnv
    ];
  };
}
