{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaEmacs =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home-manager.users.parazeeknova =
        { config, pkgs, ... }:
        {
          imports = [
            inputs.nix-doom-emacs-unstraightened.hmModule
          ];

          programs.doom-emacs = {
            enable = true;
            doomDir = ./doom.d;
          };
        };
    };
}
