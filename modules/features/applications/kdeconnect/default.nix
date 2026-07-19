{ self, inputs, ... }:

{
  flake.nixosModules.parazeeknovaKdeconnect =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      programs.kdeconnect.enable = true;

      home-manager.users.parazeeknova =
        { config, pkgs, ... }:
        {
          services.kdeconnect = {
            enable = true;
            indicator = true;
          };
        };
    };
}
