{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaZoxide = { config, pkgs, lib, ... }: {

    home-manager.users.parazeeknova.programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
      options = [
        "--cmd"
        "cd"
      ];
    };
  };
}
