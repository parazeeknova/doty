{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHyprland = { config, pkgs, lib, ... }: {

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

    home-manager.users.parazeeknova.wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      systemd.enable = false;
      configType = "lua";
      plugins = [ pkgs.hyprlandPlugins.hypr-dynamic-cursors ];
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

    environment.systemPackages = [
      inputs.hyprland-preview-share-picker.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # -- Electron Apps (Wayland) --
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # -- Environment for Hyprland --
    home-manager.users.parazeeknova.home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Hyprland";
    };

    # -- Hyprland Config files (excluding hyprland.lua, which is managed by Home Manager) --
    home-manager.users.parazeeknova.xdg.configFile = {
      "hypr/hypridle.conf".source = ./hypr/hypridle.conf;
      "hypr/hyprlock.conf".source = ./hypr/hyprlock.conf;
      "hypr/hyprlock.conf.template".source = ./hypr/hyprlock.conf.template;
      "hypr/hyprsunset.conf".source = ./hypr/hyprsunset.conf;
      "hypr/modules".source = ./hypr/modules;
      "hypr/plugins".source = ./plugins;
      "hypr/sunset.state".source = ./hypr/sunset.state;
      "hypr/xdph.conf".source = ./hypr/xdph.conf;
      "uwsm/env".source = "${config.home-manager.users.parazeeknova.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
    };

    # -- Quickshell Config --
    home-manager.users.parazeeknova.xdg.configFile."quickshell" = {
      source = ../quickshell;
      recursive = true;
    };
  };
}
