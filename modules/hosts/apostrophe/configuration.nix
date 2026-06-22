{ self, inputs, ... }: {

  flake.nixosModules.apostropheConfiguration = { config, pkgs, lib, ... }: {
    imports = [
      self.nixosModules.apostropheHardware
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.initrd.luks.devices."luks-fe7a0acb-6379-4025-aab3-05a299853e60".device = "/dev/disk/by-uuid/fe7a0acb-6379-4025-aab3-05a299853e60";

    networking.hostName = "apostrophe";
    networking.networkmanager.enable = true;

    time.timeZone = "Asia/Kolkata";
    i18n.defaultLocale = "en_IN";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_IN";
      LC_IDENTIFICATION = "en_IN";
      LC_MEASUREMENT = "en_IN";
      LC_MONETARY = "en_IN";
      LC_NAME = "en_IN";
      LC_NUMERIC = "en_IN";
      LC_PAPER = "en_IN";
      LC_TELEPHONE = "en_IN";
      LC_TIME = "en_IN";
    };

    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.graphics.enable = true;
    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };

    services.libinput.enable = true;

    users.users."parazeeknova" = {
      isNormalUser = true;
      description = "Harsh Sahu";
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [
      ];
    };

    programs.firefox.enable = true;
    nixpkgs.config.allowUnfree = true;
    environment.systemPackages = with pkgs; [
      vim
      git
      pciutils
      nodejs
    ];

    programs.nix-ld.enable = true;

    system.stateVersion = "26.05";
  };
}
