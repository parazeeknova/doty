{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHyprland = { config, pkgs, lib, ... }: {

    # -- Environment for Hyprland --
    home-manager.users.parazeeknova.home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Hyprland";
    };
  };
}
