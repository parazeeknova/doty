{ self, inputs, ... }:

{

  flake.nixosModules.parazeeknovaVscodeinsiders =
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
          # Write settings directly to the Insiders settings path
          home.file.".config/Code - Insiders/User/settings.json".text = builtins.readFile ./settings.json;
        };
    };
}
