{ self, inputs, ... }: {

  flake.nixosModules.apostropheConfiguration = { config, pkgs, lib, ... }: {
    imports = [
      self.nixosModules.apostropheHardware
      inputs.home-manager.nixosModules.home-manager
      self.nixosModules.apostrophePackages
      self.nixosModules.parazeeknovaHome
      self.nixosModules.parazeeknovaGit
      self.nixosModules.parazeeknovaFish
      self.nixosModules.parazeeknovaBash
      self.nixosModules.parazeeknovaStarship
      self.nixosModules.parazeeknovaTmux
      self.nixosModules.parazeeknovaZoxide
      self.nixosModules.parazeeknovaHyprland
      self.nixosModules.parazeeknovaWaybar
      self.nixosModules.parazeeknovaBat
      self.nixosModules.parazeeknovaBtop
      self.nixosModules.parazeeknovaCava
      self.nixosModules.parazeeknovaMako
      self.nixosModules.parazeeknovaTheming
      self.nixosModules.parazeeknovaKitty
      self.nixosModules.parazeeknovaEza
      self.nixosModules.parazeeknovaFastfetch
      self.nixosModules.parazeeknovaGhostty
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # -- Boot --
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.kernelParams = [ "nvidia-drm.modeset=1" ];
    boot.initrd.luks.devices."luks-fe7a0acb-6379-4025-aab3-05a299853e60".device = "/dev/disk/by-uuid/fe7a0acb-6379-4025-aab3-05a299853e60";

    # -- Networking --
    networking.hostName = "apostrophe";
    networking.networkmanager.enable = true;

    # -- Locale --
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

    # -- Auto Login (TTY) --
    services.getty.autologinUser = "parazeeknova";

    # -- Audio --
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # -- Services --
    services.gnome.gnome-keyring.enable = true;

    # -- Graphics --
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.graphics.enable = true;
    hardware.nvidia = {
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
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

    # -- Input --
    services.libinput.enable = true;

    # -- Environment --
    environment.sessionVariables = {
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    # -- User --
    users.users."parazeeknova" = {
      isNormalUser = true;
      description = "przknv.cc";
      extraGroups = [ "networkmanager" "wheel" ];
      shell = pkgs.fish;
    };

    # -- Misc --
    nixpkgs.config.allowUnfree = true;
    programs.nix-ld.enable = true;

    # -- Fix hardcoded /usr/share/applications for non-Nix binaries --
    systemd.tmpfiles.rules = [
      "d /usr/share 0755 root root -"
      "L /usr/share/applications - - - - /run/current-system/sw/share/applications"
    ];

    system.stateVersion = "26.05";
  };
}
