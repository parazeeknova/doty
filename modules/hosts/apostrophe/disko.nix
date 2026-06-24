{ self, inputs, ... }: {

  flake.nixosModules.apostropheDisko =
    {
      config,
      lib,
      ...
    }:
    {
      imports = [
        inputs.disko.nixosModules.disko
      ];

      # Disable disko configuration generation on the live system to prevent it from
      # overwriting the current mount settings (since the running system mounts the
      # Btrfs root filesystem directly at '/' instead of using a subvolume like 'root').
      disko.enableConfig = lib.mkDefault false;

      disko.devices = {
        disk = {
          main = {
            type = "disk";
            device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLQ1T0HBLB-00B00_S6F7NJ0T309276";
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  size = "1G";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [
                      "fmask=0077"
                      "dmask=0077"
                    ];
                  };
                };
                luks-root = {
                  size = "918.8G";
                  content = {
                    type = "luks";
                    name = "luks-58861c1a-7886-462b-81f9-e9f9b5ee79ae";
                    settings = {
                      allowDiscards = true;
                    };
                    content = {
                      type = "btrfs";
                      extraArgs = [ "-f" ];
                      subvolumes = {
                        "/root" = {
                          mountpoint = "/";
                        };
                        "/home" = {
                          mountpoint = "/home";
                        };
                        "/nix" = {
                          mountpoint = "/nix";
                        };
                      };
                    };
                  };
                };
                luks-swap = {
                  size = "100%";
                  content = {
                    type = "luks";
                    name = "luks-fe7a0acb-6379-4025-aab3-05a299853e60";
                    settings = {
                      allowDiscards = true;
                    };
                    content = {
                      type = "swap";
                      resumeDevice = true;
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
}
