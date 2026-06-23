{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaWaybar =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {

      home-manager.users.parazeeknova = { config, ... }: {
        xdg.configFile."waybar".source =
          config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/wm/waybar";
      };
    };
}
