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
        self.nixosModules.apostropheVirtualization
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        self.nixosModules.apostrophePackages
        self.nixosModules.apostropheFans
      ]
      ++ (builtins.attrValues (
        lib.filterAttrs (
          name: _:
          lib.hasPrefix "parazeeknova" name
          && !(lib.hasSuffix "Env" name || lib.hasSuffix "Aliases" name || lib.hasSuffix "Functions" name)
        ) self.nixosModules
      ));

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nix.settings.substituters = [
        "https://cache.nixos.org"
        "https://cache.nixos-cuda.org"
      ];
      nix.settings.trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
      nix.settings.trusted-users = [
        "root"
        "parazeeknova"
      ];

      # -- Boot --
      boot.loader.systemd-boot.enable = false;
      boot.loader.limine.enable = true;
      boot.loader.limine.efiInstallAsRemovable = true;
      boot.loader.limine.secureBoot.enable = true;
      boot.loader.limine.extraConfig = builtins.readFile ../../../modules/features/wm/theming/limine-theme.conf;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelPackages = pkgs.linuxPackages_latest;
      # boot.kernelParams = [
      #   "nvidia-drm.modeset=1"
      #   "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      #   "i915.enable_psr=0"
      #   "i915.enable_dc=0"
      #   "mem_sleep_default=s2idle"
      #   "nvme_core.default_ps_max_latency_us=0"
      #   "pcie_aspm=off"
      # ];
      boot.blacklistedKernelModules = [ "spd5118" ];
      boot.initrd.luks.devices."luks-fe7a0acb-6379-4025-aab3-05a299853e60".device =
        "/dev/disk/by-uuid/fe7a0acb-6379-4025-aab3-05a299853e60";

      # -- Secondary Drive Decryption --
      environment.etc."crypttab".text = ''
        crypted_second /dev/disk/by-uuid/d25f8779-8f37-41b7-bfed-a13b4291faef /etc/cryptsetup-keys.d/nvme1n1.key luks,discard
      '';

      # -- Automatic updating --
      system.autoUpgrade = {
        enable = true;
        dates = "weekly";
        flake = "/home/parazeeknova/doty#apostrophe";
        flags = [
          "--update-input"
          "nixpkgs"
          "--commit-lock-file"
        ];
      };

      systemd.services.update-zcode = {
        description = "Check and update ZCode package version and hash";
        path = [
          pkgs.git
          pkgs.nix
          pkgs.curl
          pkgs.openssh
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "parazeeknova";
          WorkingDirectory = "/home/parazeeknova/doty";
          ExecStart = "/home/parazeeknova/doty/wabi/target/release/update_zcode --commit";
        };
      };
      systemd.services.update-opencode-desktop = {
        description = "Check and update OpenCode Desktop package version and hash";
        path = [
          pkgs.git
          pkgs.nix
          pkgs.curl
          pkgs.openssh
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "parazeeknova";
          WorkingDirectory = "/home/parazeeknova/doty";
          ExecStart = "/home/parazeeknova/doty/wabi/target/release/update_opencode_desktop --commit";
        };
      };
      systemd.services.update-qoder = {
        description = "Check and update Qoder package version and hash";
        path = [
          pkgs.git
          pkgs.nix
          pkgs.curl
          pkgs.openssh
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "parazeeknova";
          WorkingDirectory = "/home/parazeeknova/doty";
          ExecStart = "/home/parazeeknova/doty/wabi/target/release/update_qoder --commit";
        };
      };
      systemd.services.update-harper = {
        description = "Check and update Harper package version and hash";
        path = [
          pkgs.git
          pkgs.nix
          pkgs.curl
          pkgs.openssh
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "parazeeknova";
          WorkingDirectory = "/home/parazeeknova/doty";
          ExecStart = "/home/parazeeknova/doty/wabi/target/release/update_harper --commit";
        };
      };
      systemd.services.nixos-upgrade.wants = [
        "update-zcode.service"
        "update-opencode-desktop.service"
        "update-qoder.service"
        "update-harper.service"
      ];
      systemd.services.nixos-upgrade.after = [
        "update-zcode.service"
        "update-opencode-desktop.service"
        "update-qoder.service"
        "update-harper.service"
      ];



      # -- Automatic cleanup --
      nix.gc.automatic = true;
      nix.gc.dates = "daily";
      nix.gc.options = "--delete-older-than 14d";
      nix.settings.auto-optimise-store = true;

      # -- Storage Optimization --
      services.fstrim.enable = true;

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
      services.cloudflare-warp.enable = true;
      services.gnome.gnome-keyring.enable = true;
      services.blueman.enable = true;
      services.upower.enable = true;
      services.tumbler.enable = true;
      services.gvfs.enable = true;
      services.udisks2.enable = true;
      services.asusd = {
        enable = true;
      };
      services.logind.settings = {
        Login = {
          HandlePowerKey = "ignore";
        };
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
      services.xserver.videoDrivers = [
        "modesetting"
        "nvidia"
      ];
      hardware.graphics.enable = true;
      hardware.nvidia = {
        modesetting.enable = true;
        open = true;
        nvidiaSettings = true;
        powerManagement = {
          enable = true;
          finegrained = true;
        };
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        dynamicBoost.enable = true;

        prime = {
          offload = {
            enable = true;
            enableOffloadCmd = true;
          };
          intelBusId = "PCI:0@0:2:0";
          nvidiaBusId = "PCI:1@0:0:0";
        };
      };

      # -- Input --
      services.libinput.enable = true;

      # -- User --
      users.users."parazeeknova" = {
        isNormalUser = true;
        description = "przknv.cc";
        extraGroups = [
          "networkmanager"
          "wheel"
          "podman"
          "libvirtd"
        ];
        shell = pkgs.fish;
      };

      # -- Misc --
      nixpkgs.config.allowUnfree = true;
      nixpkgs.config.cudaSupport = true;
      nixpkgs.config.permittedInsecurePackages = [
        "electron-40.10.5"
      ];
      nixpkgs.overlays = [
        inputs.vscode-insiders.overlays.default
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

      # -- SOPS Decryption Config --
      sops.defaultSopsFile = ../../../secrets/secrets.yaml;
      sops.age.keyFile = "${config.users.users.parazeeknova.home}/.config/sops/age/keys.txt";
      sops.secrets.mail-accounts = {
        path = "/run/secrets/mail-accounts.json";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.github-token = {
        path = "/run/secrets/github-token";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.context7-api-key = {
        path = "/run/secrets/context7-api-key";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.modal-api-key = {
        path = "/run/secrets/modal-api-key";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.anthropic-auth-token = {
        path = "/run/secrets/anthropic-auth-token";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.cloudflare-api-token = {
        path = "/run/secrets/cloudflare-api-token";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };

      system.stateVersion = "26.05";
    };
}
