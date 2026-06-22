{ self, inputs, ... }: {

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  flake.nixosConfigurations.apostrophe = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.apostropheConfiguration
    ];
  };
}
