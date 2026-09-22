{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaAagl =
    { ... }:
    {
      imports = [
        inputs.aagl.nixosModules.default
      ];

      # Configure Cachix for pre-built AAGL packages
      nix.settings = {
        substituters = [ "https://ezkea.cachix.org" ];
        trusted-public-keys = [ "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI=" ];
      };

      # Enable only the Genshin Impact launcher
      programs.anime-game-launcher.enable = true;
    };
}
