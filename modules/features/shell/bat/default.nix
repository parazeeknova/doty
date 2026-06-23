{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaBat =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      home-manager.users.parazeeknova = { config, ... }: {
        programs.bat = {
          enable = true;
        };

        xdg.configFile = {
          "bat/config".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/shell/bat/config";
          "bat/themes".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/shell/bat/themes";
        };
      };
    };
}
