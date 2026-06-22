{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHome = { config, pkgs, lib, ... }: {

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "bak";
      users.parazeeknova = { ... }: {

        home = {
          username = "parazeeknova";
          homeDirectory = "/home/parazeeknova";
          stateVersion = "24.11";
        };

        programs.home-manager.enable = true;
      };
    };
  };
}
