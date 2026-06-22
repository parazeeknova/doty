{ self, inputs, ... }: {
  flake.nixosConfigurations.apostrophe = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.apostropheConfiguration
    ];
  };
}
