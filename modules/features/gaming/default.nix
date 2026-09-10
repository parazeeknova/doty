{ self, inputs, ... }:
{
  flake.nixosModules.parazeeknovaGaming =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      lutrisPkg = pkgs.lutris.override {
        extraLibraries = pkgs: [ ];
        extraPkgs = pkgs: [
          pkgs.wineWow64Packages.stable
          pkgs.winetricks
          pkgs.gamescope
          pkgs.gamemode
          pkgs.mangohud
        ];
      };
      heroicPkg = pkgs.heroic.override {
        extraPkgs = pkgs: [
          pkgs.gamescope
          pkgs.gamemode
        ];
      };
      gpuDesktop = name: pkg: lib.hiPrio (pkgs.runCommand "offload-desktop-${name}" { } ''
        mkdir -p $out/share/applications
        for f in ${pkg}/share/applications/*.desktop; do
          [ -e "$f" ] || continue
          ${pkgs.gnused}/bin/sed 's#^Exec=#Exec=nvidia-offload #' "$f" > $out/share/applications/"$(basename "$f")"
        done
      '');
    in
    {
      imports = [ inputs.aagl.nixosModules.default ];

      nix.settings.substituters = [ "https://ezkea.cachix.org" ];
      nix.settings.trusted-public-keys = [ "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI=" ];

      programs.anime-game-launcher.enable = true;
      programs.honkers-railway-launcher.enable = true;
      programs.honkers-launcher.enable = true;
      programs.wavey-launcher.enable = true;
      programs.sleepy-launcher.enable = true;

      programs.steam = {
        enable = true;
        package = pkgs.steam.override {
          extraEnv = {
            __NV_PRIME_RENDER_OFFLOAD = "1";
            __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
            __GLX_VENDOR_LIBRARY_NAME = "nvidia";
            __VK_LAYER_NV_optimus = "NVIDIA_only";
          };
        };
        remotePlay.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        dedicatedServer.openFirewall = false;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
        extraPackages = with pkgs; [
          gamemode
          mangohud
          gamescope
        ];
        protontricks.enable = true;
        extest.enable = true;
      };

      programs.gamescope = {
        enable = true;
        capSysNice = true;
      };

      programs.gamemode = {
        enable = true;
        enableRenice = true;
        settings = {
          general = {
            inhibit_screensaver = 1;
          };
          custom = {
            start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
            end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
          };
        };
      };

      users.users."parazeeknova".extraGroups = [ "gamemode" ];

      hardware.graphics.enable32Bit = true;
      hardware.steam-hardware.enable = true;
      services.switcherooControl.enable = true;

      systemd.settings.Manager.DefaultLimitNOFILE = "524288";
      security.pam.loginLimits = [
        {
          domain = "parazeeknova";
          type = "hard";
          item = "nofile";
          value = "524288";
        }
      ];

      environment.systemPackages = with pkgs; [
        steamcmd
        protonup-qt
        umu-launcher
        lutrisPkg
        heroicPkg
        bottles
        cemu
        shadps4
        (gpuDesktop "lutris" lutrisPkg)
        (gpuDesktop "heroic" heroicPkg)
        (gpuDesktop "bottles" pkgs.bottles)
        (gpuDesktop "cemu" pkgs.cemu)
        (gpuDesktop "shadps4" pkgs.shadps4)
        (gpuDesktop "anime-game-launcher" pkgs.anime-game-launcher)
        (gpuDesktop "honkers-railway-launcher" pkgs.honkers-railway-launcher)
        (gpuDesktop "honkers-launcher" pkgs.honkers-launcher)
        (gpuDesktop "wavey-launcher" pkgs.wavey-launcher)
        (gpuDesktop "sleepy-launcher" pkgs.sleepy-launcher)
        antimicrox
        wineWow64Packages.stable
        winetricks
        mangohud
        goverlay
        vkbasalt
        gamescope
        gamemode
        nvtopPackages.full
      ];

      systemd.user.tmpfiles.rules =
        let
          compatDir = "%h/.steam/root/compatibilitytools.d";
        in
        [
          "d ${compatDir} - - - - -"
          "L+ ${compatDir}/GE-Proton - - - - ${pkgs.proton-ge-bin.steamcompattool.outPath}"
        ];

      home-manager.users.parazeeknova =
        { config, ... }:
        {
          programs.mangohud = {
            enable = true;
            enableSessionWide = false;
            settings = {
              fps = true;
              frametime = true;
              frame_timing = true;
              cpu_stats = true;
              gpu_stats = true;
              ram = true;
              vram = true;
              gamemode = true;
            };
          };

          programs.lutris = {
            enable = true;
            extraPackages = with pkgs; [
              mangohud
              gamemode
              gamescope
              winetricks
              umu-launcher
            ];
            winePackages = with pkgs; [
              wineWow64Packages.stable
            ];
          };
        };
    };
}
