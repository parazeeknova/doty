{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaStarship =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      home-manager.users.parazeeknova = { config, ... }: {
        programs.starship = {
          enable = true;
          enableFishIntegration = true;
        };

        xdg.configFile = {
          "starship.toml".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/shell/starship/starship.toml";
          "starship.toml.template".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/shell/starship/starship.toml.template";
        };
      };
    };
}
