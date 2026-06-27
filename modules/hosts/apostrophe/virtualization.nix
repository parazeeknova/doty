{ self, inputs, ... }: {
  flake.nixosModules.apostropheVirtualization =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      intelRenderNode = "/dev/dri/by-path/pci-0000:00:02.0-render";
    in
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

        # Waydroid configuration based on the guide
        waydroid.enable = true;
        waydroid.package = pkgs.waydroid-nftables;
      };

      # Network configuration for Waydroid
      networking.firewall.trustedInterfaces = [ "waydroid0" ];
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv4.conf.all.forwarding" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };

      # Disable autostart on boot for Waydroid container
      systemd.services.waydroid-container = {
        wantedBy = lib.mkForce [ ];
        serviceConfig = {
          # Enable cgroups v2 delegation (fixes "Read-only file system" errors)
          Delegate = true;
          CPUAccounting = true;
          MemoryAccounting = true;
          TasksAccounting = true;

          # GPU fix runs BEFORE container starts (no race conditions)
          ExecStartPre = lib.mkAfter [
            (pkgs.writeShellScript "waydroid-gpu-fix-pre" ''
              set -e
              PROP_FILE="/var/lib/waydroid/waydroid.prop"

              mkdir -p /var/lib/waydroid
              touch "$PROP_FILE"
              chown root:root "$PROP_FILE"
              chmod 644 "$PROP_FILE"

              # Function to set properties (removes old, adds new)
              set_prop() {
                ${pkgs.gnused}/bin/sed -i "/^$1=/d" "$PROP_FILE"
                echo "$1=$2" >> "$PROP_FILE"
              }

              # Force Intel GPU (GBM/Mesa)
              set_prop ro.hardware.gralloc gbm
              set_prop ro.hardware.egl mesa
              set_prop gralloc.gbm.device ${intelRenderNode}
              set_prop ro.hardware.vulkan intel

              # Clean empty lines
              ${pkgs.gnused}/bin/sed -i '/^$/d' "$PROP_FILE"
            '')
          ];
        };
      };

      # Backup persistence service (runs after start as fallback, only when container starts)
      systemd.services.waydroid-gpu-persistence = {
        description = "Enforce Intel GPU for Waydroid (Post-Start Backup)";
        after = [ "waydroid-container.service" ];
        bindsTo = [ "waydroid-container.service" ];
        wantedBy = [ "waydroid-container.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "waydroid-intel-fix-post" ''
            set -e
            ${pkgs.coreutils}/bin/sleep 5
            ${config.virtualisation.waydroid.package}/bin/waydroid prop set ro.hardware.gralloc gbm
            ${config.virtualisation.waydroid.package}/bin/waydroid prop set ro.hardware.egl mesa
            ${config.virtualisation.waydroid.package}/bin/waydroid prop set gralloc.gbm.device ${intelRenderNode}
            ${config.virtualisation.waydroid.package}/bin/waydroid prop set ro.hardware.vulkan intel
          '';
        };
      };

      # Passwordless sudo rules for starting/stopping the waydroid container
      security.sudo.extraRules = [
        {
          users = [ "parazeeknova" ];
          commands = [
            {
              command = "${pkgs.systemd}/bin/systemctl start waydroid-container";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.systemd}/bin/systemctl stop waydroid-container";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${pkgs.systemd}/bin/systemctl status waydroid-container";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      programs.virt-manager.enable = true;

      services.cockpit = {
        enable = true;
        settings = {
          WebService = {
            AllowUnencrypted = true;
            Origins = lib.mkForce "http://localhost:9090 https://localhost:9090 http://127.0.0.1:9090 https://127.0.0.1:9090";
          };
        };
        plugins = with pkgs; [
          cockpit-podman
          cockpit-machines
        ];
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
        libvirt
      ];
    };
}
