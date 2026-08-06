{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaPythonPackages =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        python313Packages.ddgs
      ];
    };
}
