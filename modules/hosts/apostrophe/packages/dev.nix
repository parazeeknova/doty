{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackagesDev = { config, pkgs, lib, ... }: {

    environment.systemPackages = with pkgs; [
      # -- Languages --
      nodejs
      python3
      rustup

      # -- Misc --
      jq
      yq
      ripgrep
      fd
      bat
      eza
      fzf
      zoxide
      tree-sitter
      direnv

      # -- Networking --
      wget
      curl
      openssh
      nettools
      nmap
      dig
    ];
  };
}
