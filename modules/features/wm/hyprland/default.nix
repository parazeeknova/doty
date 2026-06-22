{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHyprland = { config, pkgs, lib, ... }: {

    # -- Hyprland --
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
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

    # -- Hyprland Config --
    home-manager.users.parazeeknova.xdg.configFile."hypr" = {
      source = ./hypr;
      recursive = true;
    };

    # -- Quickshell Config --
    home-manager.users.parazeeknova.xdg.configFile."quickshell" = {
      source = ../quickshell;
      recursive = true;
    };
  };
}
