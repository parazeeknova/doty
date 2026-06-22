{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDev = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- Languages --
      nodejs
      python3
      rustup
      go
      jdk
      ruby

      # -- Package Managers --
      pnpm
      bun
      cargo
      npm
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

      # -- Containers --
      podman
      docker-compose

      # -- Database --
      sqlite
      postgresql

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
