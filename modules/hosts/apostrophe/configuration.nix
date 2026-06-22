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
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # -- Boot --
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;
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

    # -- Hyprland --
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };

    # -- Electron Apps (Wayland) --
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # -- Auto Login --
    services.displayManager.autoLogin = {
      enable = true;
      user = "parazeeknova";
    };

    # -- Audio --
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # -- Graphics --
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

    # -- Input --
    services.libinput.enable = true;

    # -- User --
    users.users."parazeeknova" = {
      isNormalUser = true;
      description = "Harsh Sahu";
      extraGroups = [ "networkmanager" "wheel" ];
    };

    # -- Misc --
    programs.firefox.enable = true;
    nixpkgs.config.allowUnfree = true;
    programs.nix-ld.enable = true;

    system.stateVersion = "26.05";
  };
}
