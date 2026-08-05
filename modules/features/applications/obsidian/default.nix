{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaObsidian =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        obsidian
      ];
    };
}
