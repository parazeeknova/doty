{ self, inputs, ... }: {

  flake.nixosModules.apostropheConfiguration =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        self.nixosModules.apostropheHardware
        self.nixosModules.apostropheDisko
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
        self.nixosModules.parazeeknovaMatugen
        self.nixosModules.parazeeknovaLazygit
        self.nixosModules.parazeeknovaHyprlandPreviewSharePicker
        self.nixosModules.parazeeknovaYazi
        self.nixosModules.parazeeknovaVim
        self.nixosModules.parazeeknovaNvim
        self.nixosModules.parazeeknovaMpd
        self.nixosModules.parazeeknovaMpv
        self.nixosModules.parazeeknovaSatty
        self.nixosModules.parazeeknovaSwappy
        self.nixosModules.parazeeknovaZathura
        self.nixosModules.parazeeknovaPypr
        self.nixosModules.parazeeknovaOpencode
        self.nixosModules.parazeeknovaSpicetify
        self.nixosModules.parazeeknovaVesktop
        self.nixosModules.parazeeknovaScripts
        self.nixosModules.parazeeknovaZen
      ];

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      # -- Boot --
      boot.loader.systemd-boot.enable = false;
      boot.loader.limine.enable = true;
      boot.loader.limine.efiInstallAsRemovable = true;
      boot.loader.limine.secureBoot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelPackages = pkgs.linuxPackages_latest;
      boot.kernelParams = [
        "nvidia-drm.modeset=1"
        "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        "i915.enable_psr=0"
        "mem_sleep_default=s2idle"
      ];
      boot.blacklistedKernelModules = [ "spd5118" ];
      boot.initrd.luks.devices."luks-fe7a0acb-6379-4025-aab3-05a299853e60".device =
        "/dev/disk/by-uuid/fe7a0acb-6379-4025-aab3-05a299853e60";

      # -- Automatic updating --
      system.autoUpgrade.enable = true;
      system.autoUpgrade.dates = "weekly";

      # -- Automatic cleanup --
      nix.gc.automatic = true;
      nix.gc.dates = "daily";
      nix.gc.options = "--delete-older-than 14d";
      nix.settings.auto-optimise-store = true;

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

      # -- Security --
      security.sudo.extraConfig = ''
        Defaults pwfeedback
        Defaults insults
      '';

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
      services.blueman.enable = true;
      services.upower.enable = true;
      services.tumbler.enable = true;
      services.gvfs.enable = true;
      services.udisks2.enable = true;
      services.asusd = {
        enable = true;
      };

      # -- Bluetooth --
      hardware.bluetooth.enable = true;

      # -- File Manager & Thumbnails --
      programs.thunar = {
        enable = true;
        plugins = with pkgs; [
          thunar-volman
          thunar-archive-plugin
          thunar-vcs-plugin
          thunar-shares-plugin
          thunar-media-tags-plugin
        ];
      };

      environment.pathsToLink = [ "/share/thumbnailers" ];

      # -- Graphics --
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.graphics.enable = true;
      hardware.nvidia = {
        modesetting.enable = true;
        open = false;
        nvidiaSettings = true;
        powerManagement = {
          enable = true;
          finegrained = false;
        };
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        dynamicBoost.enable = true;
      };

      # -- Input --
      services.libinput.enable = true;

      # -- Environment --
      environment.sessionVariables = {
        # On Optimus (Intel + NVIDIA) offload mode, the Wayland compositor should run on the integrated GPU (Intel).
        # Setting these globally forces Hyprland onto the NVIDIA GPU, causing frequent crashes/freezes.
        # GBM_BACKEND = "nvidia-drm";
        # __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        # WLR_NO_HARDWARE_CURSORS = "1";
      };

      # -- User --
      users.users."parazeeknova" = {
        isNormalUser = true;
        description = "przknv.cc";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        shell = pkgs.fish;
      };

      # -- Misc --
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        (final: prev: {
          thunar-unwrapped = prev.thunar-unwrapped.overrideAttrs (oldAttrs: {
            postPatch = (oldAttrs.postPatch or "") + ''
              sed -i 's/#define BORDER_RADIUS 8/#define BORDER_RADIUS 0/g' thunar/thunar-util.c
            '';
          });
        })
      ];
      programs.nix-ld.enable = true;

      # -- Fix hardcoded /usr/share/applications for non-Nix binaries --
      systemd.tmpfiles.rules = [
        "d /usr/share 0755 root root -"
        "L /usr/share/applications - - - - /run/current-system/sw/share/applications"
      ];

      system.stateVersion = "26.05";
    };
}
