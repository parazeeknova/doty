{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaAagl =
    { pkgs, lib, ... }:
    {
      imports = [
        inputs.aagl.nixosModules.default
      ];

      # Configure Cachix for pre-built AAGL packages
      nix.settings = {
        substituters = [ "https://ezkea.cachix.org" ];
        trusted-public-keys = [ "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI=" ];
      };

      # Enable Genshin Impact launcher with wrapped ulimit to prevent file exhaustion crashes
      programs.anime-game-launcher = {
        enable = true;
        package =
          let
            original = inputs.aagl.packages.${pkgs.stdenv.hostPlatform.system}.anime-game-launcher;
          in
          pkgs.symlinkJoin {
            name = "anime-game-launcher-wrapped-${original.version or "3.19.8"}";
            paths = [ original ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/anime-game-launcher \
                --run "ulimit -n 524288 2>/dev/null"
            '';
          };
      };

      # Wine, FSync, and Genshin asset streaming require a high file descriptor limit
      security.pam.loginLimits = [
        {
          domain = "*";
          type = "-";
          item = "nofile";
          value = "524288";
        }
      ];

      # Ensure user session and systemd services/scopes inherit high file limits
      systemd.user.settings.Manager = {
        DefaultLimitNOFILE = "524288:524288";
      };
      systemd.settings.Manager = {
        DefaultLimitNOFILE = "524288:524288";
      };

      # Kernel max_map_count for Wine/Proton to prevent mmap ENOMEM allocation failures
      boot.kernel.sysctl = {
        "vm.max_map_count" = lib.mkForce 2147483642;
      };
    };
}
