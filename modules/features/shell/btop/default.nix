{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaBtop = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova = { config, ... }: {
      programs.btop = {
        enable = true;
      };

      xdg.configFile = {
        "btop/btop.conf".source = config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/shell/btop/btop.conf";
        "btop/themes".source = config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/shell/btop/themes";
      };
    };
  };
}
