{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaCava = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, ... }: {
      programs.cava = {
        enable = true;
      };

      xdg.configFile = {
        "cava/config".source = config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/shell/cava/config";
        "cava/config.template".source = config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/shell/cava/config.template";
      };
    };
  };
}
