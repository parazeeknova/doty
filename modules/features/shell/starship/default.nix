{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaStarship = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.starship = {
      enable = true;
      enableFishIntegration = true;
    };

    home-manager.users.parazeeknova.xdg.configFile."starship.toml" = {
      source = ./starship.toml;
      force = true;
    };
  };
}
