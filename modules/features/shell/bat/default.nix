{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaBat = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.bat = {
      enable = true;
    };

    home-manager.users.parazeeknova.xdg.configFile = {
      "bat/config".source = ./config;
      "bat/themes".source = ./themes;
    };
  };
}
