{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaGaming =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        inputs.aagl.nixosModules.default
      ];

      # Set up Cachix binary cache for aagl-gtk-on-nix
      nix.settings = inputs.aagl.nixConfig;

      # Enable an-anime-team launchers
      programs.anime-game-launcher.enable = true; # Genshin Impact

      # Enable Steam
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        gamescopeSession.enable = true;
      };

      # Enable GameMode to optimize system performance during gaming
      programs.gamemode = {
        enable = true;
        enableRenice = true;
        settings = {
          general = {
            softrealtime = "auto";
            renice = 10;
          };
        };
      };

      # Useful packages for gaming
      environment.systemPackages = with pkgs; [
        wineWow64Packages.stable
        protonplus
        winetricks
        vkd3d-proton
        mangohud
        gamescope
        gamemode
      ];
    };
}
