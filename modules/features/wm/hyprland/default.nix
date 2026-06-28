{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHyprland =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      hypr-kinetic-scroll = pkgs.stdenv.mkDerivation {
        pname = "hypr-kinetic-scroll";
        version = "unstable";

        src = inputs.hypr-kinetic-scroll;

        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [
          pkgs.hyprland
          pkgs.aquamarine
          pkgs.hyprgraphics
          pkgs.hyprutils
          pkgs.hyprlang
          pkgs.hyprcursor
          pkgs.libGL
          pkgs.libxcb-wm
          pkgs.libxcb-errors
          pkgs.wayland-protocols
          pkgs.lua
          pkgs.pixman
          pkgs.libdrm
          pkgs.libinput
          pkgs.systemd
          pkgs.wayland
          pkgs.libxkbcommon
          pkgs.pango
          pkgs.cairo
        ];

        buildPhase = ''
          runHook preBuild
          make
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib
          cp hypr-kinetic-scroll.so $out/lib/libhypr-kinetic-scroll.so
          runHook postInstall
        '';
      };

      hyprland-scroll-overview = pkgs.stdenv.mkDerivation {
        pname = "hyprland-scroll-overview";
        version = "unstable";

        src = inputs.hyprland-scroll-overview;

        nativeBuildInputs = [
          pkgs.pkg-config
          pkgs.cmake
          pkgs.gcc14
        ];
        buildInputs = [
          pkgs.hyprland
          pkgs.aquamarine
          pkgs.hyprgraphics
          pkgs.hyprutils
          pkgs.hyprlang
          pkgs.hyprcursor
          pkgs.libGL
          pkgs.libxcb-wm
          pkgs.libxcb-errors
          pkgs.wayland-protocols
          pkgs.lua5_4
          pkgs.pixman
          pkgs.libdrm
          pkgs.libinput
          pkgs.systemd
          pkgs.wayland
          pkgs.libxkbcommon
          pkgs.pango
          pkgs.cairo
          pkgs.glslang
        ];
      };
    in
    {

      # -- Hyprland --
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
        portalPackage = pkgs.xdg-desktop-portal-hyprland;
        withUWSM = true;
      };

      # -- Dconf GTK Settings --
      programs.dconf.profiles.user.databases = [
        {
          settings."org/gnome/desktop/interface" = {
            gtk-theme = "wabi";
            icon-theme = "Papirus-Dark";
            cursor-theme = "capitaine-cursors";
            cursor-size = lib.gvariant.mkInt32 24;
            font-name = "FiraCode Nerd Font 9";
            document-font-name = "FiraCode Nerd Font 9";
            monospace-font-name = "FiraCode Nerd Font 9";
          };
        }
      ];

      environment.systemPackages = [
        inputs.hyprland-preview-share-picker.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];

      # -- Electron Apps (Wayland) --
      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      home-manager.users.parazeeknova = { config, ... }: {
        wayland.windowManager.hyprland = {
          enable = true;
          package = null;
          portalPackage = null;
          systemd.enable = false;
          configType = "lua";
          plugins = [
            pkgs.hyprlandPlugins.hypr-dynamic-cursors
            pkgs.hyprlandPlugins.hyprfocus
            hypr-kinetic-scroll
            hyprland-scroll-overview
          ];
          extraConfig = ''
            -- Load main hyprland configuration modules
            local function safe_require(module)
                local status, err = pcall(require, module)
                if not status then
                    local msg = "Failed to load Hyprland module: " .. tostring(module) .. "\nError: " .. tostring(err)
                    print(msg)
                    os.execute("notify-send -u critical -a 'Hyprland' 'Config Error' '" .. msg:gsub("'", "'\\'''") .. "'")
                end
            end

            safe_require('modules.core.monitors')
            safe_require('modules.core.input')
            safe_require('modules.binds')
            safe_require('modules.autostart')
            safe_require('modules.env')
            safe_require('modules.decorations')
            safe_require('modules.layout')
            safe_require('modules.misc')
            safe_require('modules.windowrules')
            safe_require('modules.workspace.rules')
          '';
        };

        home.sessionVariables = {
          XDG_CURRENT_DESKTOP = "Hyprland";
          XDG_SESSION_TYPE = "wayland";
          XDG_SESSION_DESKTOP = "Hyprland";
        };

        xdg.configFile = {
          "hypr/hypridle.conf".source = ./hypr/hypridle.conf;
          "hypr/hyprlock.conf".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/wm/hyprland/hypr/hyprlock.conf";
          "hypr/hyprlock.conf.template".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/wm/hyprland/hypr/hyprlock.conf.template";
          "hypr/hyprsunset.conf".source = ./hypr/hyprsunset.conf;
          "hypr/modules".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/wm/hyprland/hypr/modules";
          "hypr/plugins".source = ./plugins;
          "hypr/sunset.state".source =
            config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/wm/hyprland/hypr/sunset.state";
          "hypr/xdph.conf".source = ./hypr/xdph.conf;
          "uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
        };

        # -- Quickshell Config --
        xdg.configFile."quickshell".source =
          config.lib.file.mkOutOfStoreSymlink "/home/parazeeknova/doty/modules/features/wm/quickshell";
      };
    };
}
