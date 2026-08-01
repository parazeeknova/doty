{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaTailscale =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      # Enable Tailscale service and open required firewall ports
      services.tailscale = {
        enable = true;
        openFirewall = true;
        useRoutingFeatures = "client";
        extraUpFlags = [
          "--ssh"
        ];
      };

      # Enable OpenSSH server for SSH access from phone / remote devices
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = true;
          PermitRootLogin = "no";
        };
        openFirewall = true;
      };

      # Allow traffic through Tailscale interface
      networking.firewall.trustedInterfaces = [ "tailscale0" ];

      # Enable Mosh (Mobile Shell) for resilient mobile terminal connections
      programs.mosh = {
        enable = true;
        openFirewall = true;
      };

      # System packages
      environment.systemPackages = [ pkgs.tailscale ];
    };
}
