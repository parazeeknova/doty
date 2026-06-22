{ self, inputs, ... }: {

  flake.nixosModules.apostropheHardware = { lib, pkgs, modulesPath, ... }: {
    imports =
      [ (modulesPath + "/installer/scan/not-detected.nix")
      ];

    boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "vmd" "nvme" "usb_storage" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.extraModulePackages = [ ];

    fileSystems."/" =
      { device = "/dev/mapper/luks-58861c1a-7886-462b-81f9-e9f9b5ee79ae";
        fsType = "btrfs";
      };

    boot.initrd.luks.devices."luks-58861c1a-7886-462b-81f9-e9f9b5ee79ae".device = "/dev/disk/by-uuid/58861c1a-7886-462b-81f9-e9f9b5ee79ae";

    fileSystems."/home" =
      { device = "/dev/mapper/luks-58861c1a-7886-462b-81f9-e9f9b5ee79ae";
        fsType = "btrfs";
        options = [ "subvol=home" ];
      };

    fileSystems."/nix" =
      { device = "/dev/mapper/luks-58861c1a-7886-462b-81f9-e9f9b5ee79ae";
        fsType = "btrfs";
        options = [ "subvol=nix" ];
      };

    fileSystems."/boot" =
      { device = "/dev/disk/by-uuid/9A8C-633C";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };

    swapDevices =
      [ { device = "/dev/mapper/luks-fe7a0acb-6379-4025-aab3-05a299853e60"; }
      ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  };
}
