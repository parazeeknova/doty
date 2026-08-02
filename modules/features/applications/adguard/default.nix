{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaAdguard =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      # Enable AdGuard Home for local and Tailscale network ad-blocking
      services.adguardhome = {
        enable = true;
        openFirewall = true;
        host = "0.0.0.0";
        port = 3080;
        mutableSettings = true;
        settings = {
          dns = {
            bind_hosts = [
              "127.0.0.1"
              "100.72.83.48"
            ];
            port = 53;
            upstream_dns = [
              "https://dns.quad9.net/dns-query"
              "https://dns.cloudflare.com/dns-query"
              "tls://dns.google"
              "1.1.1.1"
              "9.9.9.9"
            ];
            fastest_addr = true;
          };
          filtering = {
            protection_enabled = true;
            filtering_enabled = true;
          };
        };
      };

      # Update existing AdGuardHome.yaml if generated during initial failed attempt
      systemd.services.adguardhome.preStart = lib.mkAfter ''
        if [ -f /var/lib/AdGuardHome/AdGuardHome.yaml ]; then
          ${pkgs.gnused}/bin/sed -i 's/- 0\.0\.0\.0/- 127.0.0.1\n    - 100.72.83.48/' /var/lib/AdGuardHome/AdGuardHome.yaml || true
        fi
      '';

      # Disable systemd-resolved DNS stub listener so AdGuard Home can bind to port 53
      services.resolved = {
        enable = true;
        settings = {
          Resolve = {
            DNSStubListener = "no";
          };
        };
      };
      # Route laptop local DNS queries to AdGuard Home
      networking.nameservers = [ "127.0.0.1" ];
    };
}
