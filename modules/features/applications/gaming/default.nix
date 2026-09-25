{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaGaming =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        # -- Game Launchers & Managers --
        (bottles.override {
          removeWarningPopup = true;
          withObsVkCapture = true;
        })
        heroic
        (lutris.override {
          extraPkgs = pkgs: [
            pkgs.wineWow64Packages.waylandFull
            pkgs.winetricks
            pkgs.gamescope
            pkgs.mangohud
          ];
        })
        protonup-qt

        # -- Compatibility & Runtimes --
        wineWow64Packages.waylandFull
        winetricks

        # -- Performance & HUD --
        mangohud
        goverlay
        vkbasalt
      ];

      # Flatpak support for containerized Bottles runners or flatpak games
      services.flatpak.enable = true;

      # System optimizations for gaming, Wine, and large memory mappings
      boot.kernel.sysctl = {
        "vm.max_map_count" = lib.mkDefault 2147483642;
        "fs.file-max" = lib.mkDefault 524288;
      };
    };
}
