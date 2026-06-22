{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDev = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
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
      vscode
      ghostty
      kitty

      # -- API Tools --
      httpie
    ];
  };
}
