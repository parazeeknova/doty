{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaSteam =
    { pkgs, lib, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = false;
        localNetworkGameTransfers.openFirewall = true;
        gamescopeSession.enable = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
      };

      programs.gamescope = {
        enable = true;
        capSysNice = true;
      };

      hardware.graphics.enable32Bit = lib.mkDefault true;
    };
}
