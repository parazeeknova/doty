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

        # Enable libvirtd daemon for QEMU virtual machines
        libvirtd = {
          enable = true;
          qemu = {
            package = pkgs.qemu_kvm;
            runAsRoot = true;
            swtpm.enable = true;
          };
        };

        # Enable VMware Workstation host service
        vmware.host.enable = true;
      };

      programs.virt-manager.enable = true;

      services.cockpit = {
        enable = true;
      };

      # Automatically define and autostart the default NAT network
      systemd.services.libvirtd-default-network = {
        description = "Autostart libvirt default network";
        after = [ "libvirtd.service" ];
        requires = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.libvirt}/bin/virsh net-start default || true; ${pkgs.libvirt}/bin/virsh net-autostart default || true'";
        };
      };

      environment.systemPackages = with pkgs; [
        dive
        podman-tui
        podman-desktop
        podman-compose
        distrobox
        cockpit
        cockpit-podman
        cockpit-machines
        libvirt
      ];
    };
}
