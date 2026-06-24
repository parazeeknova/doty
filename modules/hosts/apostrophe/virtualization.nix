{ self, inputs, ... }: {
  flake.nixosModules.apostropheVirtualization =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      # Enable common container config files in /etc/containers
      virtualisation.containers.enable = true;
      virtualisation = {
        podman = {
          enable = true;
          dockerCompat = true;
          defaultNetwork.settings.dns_enabled = true;
        };
      };

      # Useful other packages
      environment.systemPackages = with pkgs; [
        dive
        podman-tui
        podman-desktop
        podman-compose
      ];
    };
}
