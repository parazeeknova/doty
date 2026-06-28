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
      programs.anime-game-launcher.enable = true;      # Genshin Impact
      programs.anime-games-launcher.enable = true;     # Multiple games
      programs.honkers-railway-launcher.enable = false; # Honkai: Star Rail
      programs.honkers-launcher.enable = false;         # Honkai Impact 3rd
      programs.wavey-launcher.enable = true;           # Wuthering Waves
      programs.sleepy-launcher.enable = false;          # Zenless Zone Zero

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
        heroic
        lutris
      ];
    };
}
