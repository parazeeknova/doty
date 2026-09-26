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
        "https://cache.nixos-cuda.org"
        "https://cache.nixos.org"
      ];
      nix.settings.trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
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
      security.pki.certificateFiles = [
        ../../../certs/portless-ca.pem
      ];

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
        linger = true;
        extraGroups = [
          "networkmanager"
          "wheel"
          "podman"
          "libvirtd"
          "kvm"
          "adbusers"
        ];
        shell = pkgs.fish;
      };

      users.groups.adbusers = { };

      # -- Polkit & Sudo rules for systemctl --
      security.sudo.extraRules = [
        {
          users = [ "parazeeknova" ];
          commands = [
            {
              command = "/run/current-system/sw/bin/systemctl";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
            if ((action.id == "org.freedesktop.systemd1.manage-units" ||
                 action.id == "org.freedesktop.systemd1.manage-unit-files") &&
                subject.user == "parazeeknova") {
                return polkit.Result.YES;
            }
        });
      '';

      # -- Misc --
      nixpkgs.config.allowUnfree = true;
      nixpkgs.config.android_sdk.accept_license = true;
      nixpkgs.config.permittedInsecurePackages = [
        "electron-40.10.5"
        "electron-39.8.10"
        "electron-39.8.1"
      ];
      nixpkgs.overlays = [
        inputs.vscode-insiders.overlays.default
        (final: prev: {
          hyprland = prev.hyprland.overrideAttrs (oldAttrs: {
            buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ prev.glaze ];
            postPatch = (oldAttrs.postPatch or "") + ''
              sed -i 's/find_package(glaze 7\.\.\.<8 QUIET)/find_package(glaze QUIET)/g' CMakeLists.txt
            '';
          });
          thunar-unwrapped = prev.thunar-unwrapped.overrideAttrs (oldAttrs: {
            postPatch = (oldAttrs.postPatch or "") + ''
              sed -i 's/#define BORDER_RADIUS 8/#define BORDER_RADIUS 0/g' thunar/thunar-util.c
            '';
          });
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (pfinal: pprev: {
              inline-snapshot = pprev.inline-snapshot.overridePythonAttrs (_: {
                doCheck = false;
              });
              sse-starlette = pprev.sse-starlette.overridePythonAttrs (_: {
                doCheck = false;
                dependencies = (pprev.dependencies or [ ]) ++ [ pfinal.starlette ];
              });
            })
          ];
        })
      ];
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          stdenv.cc.cc.lib
          zlib
          glib
          libx11
          libxi
          libxtst
          libxext
          libxrandr
          libxcursor
          libxfixes
          libxrender
          libxcomposite
          libxdamage
          libxcb
          libxkbcommon
          libxkbfile
          libxshmfence
          alsa-lib
          libdrm
          libgbm
          mesa
          nss
          nspr
          cairo
          pango
          atk
          at-spi2-atk
          at-spi2-core
          gtk3
          gdk-pixbuf
          udev
          vulkan-loader
          libGL
          openssl
          curl
        ];
      };

      # -- Fix hardcoded /usr/share/applications for non-Nix binaries --
      systemd.tmpfiles.rules = [
        "d /usr/share 0755 root root -"
        "L /usr/share/applications - - - - /run/current-system/sw/share/applications"
      ];

      # Some installers (hermes cua-driver, etc.) hardcode /bin/bash, but
      # NixOS has no FHS /bin. Mirror the built-in `binsh` activation snippet
      # to provide /bin/bash for those scripts.
      system.activationScripts.binbash = lib.mkAfter ''
        ln -sfn ${pkgs.bashInteractive}/bin/bash /bin/.bash.tmp
        mv /bin/.bash.tmp /bin/bash # atomically replace /bin/bash
      '';

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
      sops.secrets.openrouter-api-key = {
        path = "/run/secrets/openrouter-api-key";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.anthropic-api-key = {
        path = "/run/secrets/anthropic-api-key";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.merge-gateway-api-key = {
        path = "/run/secrets/merge-gateway-api-key";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      # -- Merge Gateway per-account keys (mg_popup, N=1..6) --
      sops.secrets.mg-mgmt-key-1 = {
        path = "/run/secrets/mg-mgmt-key-1";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-gateway-key-1 = {
        path = "/run/secrets/mg-gateway-key-1";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-mgmt-key-2 = {
        path = "/run/secrets/mg-mgmt-key-2";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-gateway-key-2 = {
        path = "/run/secrets/mg-gateway-key-2";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-mgmt-key-3 = {
        path = "/run/secrets/mg-mgmt-key-3";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-gateway-key-3 = {
        path = "/run/secrets/mg-gateway-key-3";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-mgmt-key-4 = {
        path = "/run/secrets/mg-mgmt-key-4";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-gateway-key-4 = {
        path = "/run/secrets/mg-gateway-key-4";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-mgmt-key-5 = {
        path = "/run/secrets/mg-mgmt-key-5";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-gateway-key-5 = {
        path = "/run/secrets/mg-gateway-key-5";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-mgmt-key-6 = {
        path = "/run/secrets/mg-mgmt-key-6";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };
      sops.secrets.mg-gateway-key-6 = {
        path = "/run/secrets/mg-gateway-key-6";
        owner = config.users.users.parazeeknova.name;
        group = "users";
        mode = "0400";
      };

      system.stateVersion = "26.05";
    };
}
