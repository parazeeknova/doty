{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaCava = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.cava = {
      enable = true;
    };

    home-manager.users.parazeeknova.xdg.configFile = {
      "cava/config".source = ./config;
      "cava/config.template".source = ./config.template;
    };
  };
}
