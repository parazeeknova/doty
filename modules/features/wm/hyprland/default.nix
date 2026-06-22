{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHyprland = { config, pkgs, lib, ... }: {

    # -- Hyprland --
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };

    # -- Electron Apps (Wayland) --
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # -- Environment for Hyprland --
    home-manager.users.parazeeknova.home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Hyprland";
    };
  };
}
