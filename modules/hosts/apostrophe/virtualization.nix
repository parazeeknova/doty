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
              BASE_PROP_FILE="/var/lib/waydroid/waydroid_base.prop"

              mkdir -p /var/lib/waydroid
              touch "$PROP_FILE"
              chown root:root "$PROP_FILE"
              chmod 644 "$PROP_FILE"

              # Function to set properties (removes old, adds new)
              set_prop() {
                local file="$1"
                local key="$2"
                local val="$3"
                ${pkgs.gnused}/bin/sed -i "/^$key=/d" "$file"
                echo "$key=$val" >> "$file"
              }

              # Function to delete properties
              del_prop() {
                local file="$1"
                local key="$2"
                ${pkgs.gnused}/bin/sed -i "/^$key=/d" "$file"
              }

              # Setup waydroid.prop
              set_prop "$PROP_FILE" ro.hardware.gralloc gbm
              set_prop "$PROP_FILE" ro.hardware.egl mesa
              set_prop "$PROP_FILE" gralloc.gbm.device ${intelRenderNode}
              del_prop "$PROP_FILE" ro.hardware.vulkan
              del_prop "$PROP_FILE" gralloc.gbm.legacy

              # Setup waydroid_base.prop (if it exists)
              if [ -f "$BASE_PROP_FILE" ]; then
                set_prop "$BASE_PROP_FILE" ro.hardware.gralloc gbm
                set_prop "$BASE_PROP_FILE" ro.hardware.egl mesa
                set_prop "$BASE_PROP_FILE" gralloc.gbm.device ${intelRenderNode}
                del_prop "$BASE_PROP_FILE" ro.hardware.vulkan
                del_prop "$BASE_PROP_FILE" gralloc.gbm.legacy
              fi

              # Clean empty lines
              ${pkgs.gnused}/bin/sed -i '/^$/d' "$PROP_FILE"
              if [ -f "$BASE_PROP_FILE" ]; then
                ${pkgs.gnused}/bin/sed -i '/^$/d' "$BASE_PROP_FILE"
              fi
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
            
            PROP_FILE="/var/lib/waydroid/waydroid.prop"
            BASE_PROP_FILE="/var/lib/waydroid/waydroid_base.prop"
            
            for f in "$PROP_FILE" "$BASE_PROP_FILE"; do
              if [ -f "$f" ]; then
                ${pkgs.gnused}/bin/sed -i '/^ro.hardware.vulkan=/d' "$f"
                ${pkgs.gnused}/bin/sed -i '/^gralloc.gbm.legacy=/d' "$f"
              fi
            done
          '';
        };
      };

      # Passwordless sudo rules for starting/stopping the waydroid container
      security.sudo.extraRules = [
        {
          users = [ "parazeeknova" ];
          commands = [
            {
              command = "/run/current-system/sw/bin/systemctl start waydroid-container";
              options = [ "NOPASSWD" ];
            }
            {
              command = "/run/current-system/sw/bin/systemctl stop waydroid-container";
              options = [ "NOPASSWD" ];
            }
            {
              command = "/run/current-system/sw/bin/systemctl status waydroid-container";
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
