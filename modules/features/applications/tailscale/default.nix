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
        extraSetFlags = [
          "--operator=parazeeknova"
        ];
      };

      # Allow user parazeeknova to run tailscale up/down/set without password
      security.sudo.extraRules = [
        {
          users = [ "parazeeknova" ];
          commands = [
            {
              command = "/run/current-system/sw/bin/tailscale";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

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
