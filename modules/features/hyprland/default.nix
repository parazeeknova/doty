{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaHyprland = { config, pkgs, lib, ... }: {

    # -- Systemd User Service for uwsm/Hyprland --
    systemd.user.services.uwsm = {
      description = "Universal Wayland Session Manager";
      after = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.uwsm}/bin/uwsm start hyprland.desktop";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # -- Environment for uwsm --
    home-manager.users.parazeeknova.home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Hyprland";
    };
  };
}
