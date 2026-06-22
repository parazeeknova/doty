{ self, inputs, ... }: {

  flake.nixosModules.apostrophePackages = { config, pkgs, lib, ... }: {
    imports = [
      self.nixosModules.apostrophePackagesDesktop
      self.nixosModules.apostrophePackagesDev
      self.nixosModules.apostrophePackagesCli
    ];
  };
}
