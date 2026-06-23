{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaBtop = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.btop = {
      enable = true;
    };

    home-manager.users.parazeeknova.xdg.configFile = {
      "btop/btop.conf".source = ./btop.conf;
      "btop/themes".source = ./themes;
    };
  };
}
