{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaBash =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      home-manager.users.parazeeknova.programs.bash = {
        enable = true;
        shellAliases = {
          # -- NixOS --
          doty = "cd ~/doty && make rebuild";
          dotes = "cd ~/doty && sudo nixos-rebuild test --flake .#apostrophe";
          nfu = "nix flake update";
          nfc = "nix flake check";
          nfsh = "nix flake show";
          nsh = "nix shell";
          npl = "nix profile list";
          npr = "nix profile remove";
          nps = "nix profile sync";
          ncg = "nix-collect-garbage -d";
          nso = "nix store optimise";
          nb = "nix build";
          nr = "nix run";
          ne = "nix eval";
        };
      };
    };
}
