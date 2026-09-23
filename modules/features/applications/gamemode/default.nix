{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaGamemode =
    { pkgs, ... }:
    {
      programs.gamemode = {
        enable = true;
        enableRenice = true;
        settings = {
          general = {
            renice = 10;
          };
          custom = {
            start = "${pkgs.libnotify}/bin/notify-send -a 'GameMode' 'GameMode started'";
            end = "${pkgs.libnotify}/bin/notify-send -a 'GameMode' 'GameMode ended'";
          };
        };
      };

      users.users.parazeeknova.extraGroups = [ "gamemode" ];
    };
}
