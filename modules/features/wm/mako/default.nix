{ self, ... }: {
  
  flake.nixosModules.parazeeknovaMako = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.services.mako = {
      enable = true;
    };

    home-manager.users.parazeeknova.xdg.configFile = {
      "mako/config".source = config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/wm/mako/config";
      "mako/config.template".source = config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/wm/mako/config.template";
    };
  };
}
