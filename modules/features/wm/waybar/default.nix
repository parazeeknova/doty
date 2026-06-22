{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaWaybar = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.xdg.configFile."waybar" = {
      source = ./.;
      recursive = true;
    };
  };
}
