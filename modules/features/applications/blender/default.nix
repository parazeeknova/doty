{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaBlender =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        blender
      ];
    };
}
