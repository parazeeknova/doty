{ self, inputs, ... }: {
  flake.nixosModules.parazeeknovaMobile =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # An FHS environment for running prebuilt binaries downloaded by Gradle/Android SDK
      # (e.g. aapt2, NDK clang, emulator) without NixOS dynamic linker issues.
      android-fhs = pkgs.buildFHSEnv {
        name = "android-fhs";
        targetPkgs =
          pkgs: with pkgs; [
            # Android & Java
            jdk17
            gradle
            android-tools
            watchman
            eas-cli
            bundletool
            scrcpy

            # Node & Package Managers
            nodejs
            pnpm
            bun
            yarn

            # Build Tools & Compilers
            pkg-config
            gnumake
            gcc
            cmake
            ninja

            # Core Native Libraries
            glibc
            glibc.dev
            zlib
            ncurses5
            libxml2
            openssl
            stdenv.cc.cc.lib

            # GUI / Graphics Libraries (for emulator & UI tools)
            libGL
            alsa-lib
            fontconfig
            freetype
            xorg.libX11
            xorg.libXext
            xorg.libXrender
            xorg.libXtst
            xorg.libXi
            xorg.libXrandr
          ];
        multiPkgs =
          pkgs: with pkgs; [
            zlib
            ncurses5
          ];
        runScript = "fish";
        profile = ''
          export ANDROID_HOME="$HOME/Android/Sdk"
          export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
          export JAVA_HOME="${pkgs.jdk17.home}"
          export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$PATH"
        '';
      };
    in
    {
      # Accept Android SDK license agreement for unfree packages
      nixpkgs.config.android_sdk.accept_license = true;

      # System packages for Mobile Development (React Native, Expo, Android)
      environment.systemPackages = with pkgs; [
        # Android Studio IDE & Emulator
        android-studio

        # Android SDK CLI & Device Debugging Tools
        android-tools
        bundletool
        scrcpy
        usbutils

        # Java & Build System (React Native standard is JDK 17)
        jdk17
        gradle

        # File watcher for React Native / Expo Metro bundler
        watchman

        # Expo Application Services CLI
        eas-cli

        # FHS environment wrapper for seamless Gradle/NDK execution
        android-fhs
      ];

      # Environment variables system-wide
      environment.sessionVariables = {
        ANDROID_HOME = "$HOME/Android/Sdk";
        ANDROID_SDK_ROOT = "$HOME/Android/Sdk";
        JAVA_HOME = "${pkgs.jdk17.home}";
      };

      # ADB and KVM User Groups
      users.groups.adbusers = { };
      users.users.parazeeknova.extraGroups = [
        "adbusers"
        "kvm"
      ];

      # Increase inotify watches for React Native Metro bundler and Expo
      boot.kernel.sysctl = {
        "fs.inotify.max_user_watches" = 524288;
        "fs.inotify.max_user_instances" = 8192;
      };

      # Additional dynamic libraries for nix-ld to support Android build tools & NDK binaries
      programs.nix-ld.libraries = with pkgs; [
        libxml2
        ncurses5
      ];

      # Shell integration in Fish for interactive sessions
      home-manager.users.parazeeknova =
        { config, pkgs, ... }:
        {
          programs.fish.shellInit = ''
            # -- Android & Mobile Development --
            set -gx ANDROID_HOME "$HOME/Android/Sdk"
            set -gx ANDROID_SDK_ROOT "$HOME/Android/Sdk"
            set -gx JAVA_HOME "${pkgs.jdk17.home}"

            fish_add_path $HOME/Android/Sdk/emulator
            fish_add_path $HOME/Android/Sdk/platform-tools
            fish_add_path $HOME/Android/Sdk/cmdline-tools/latest/bin
            fish_add_path $HOME/Android/Sdk/tools/bin
            fish_add_path $HOME/Android/Sdk/tools
          '';
        };
    };

  # Dedicated mobile development devShell: run with `nix develop .#mobile`
  perSystem =
    { pkgs, ... }:
    {
      devShells.mobile = pkgs.mkShell {
        name = "mobile-dev";

        nativeBuildInputs = with pkgs; [
          android-studio
          android-tools
          jdk17
          gradle
          watchman
          eas-cli
          bundletool
          scrcpy
          nodejs
          bun
          pnpm
          yarn
        ];

        shellHook = ''
          export ANDROID_HOME="$HOME/Android/Sdk"
          export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
          export JAVA_HOME="${pkgs.jdk17.home}"
          export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$PATH"
          echo "📱 Android & React Native (Expo) Dev Environment Loaded!"
          echo "   • ANDROID_HOME: $ANDROID_HOME"
          echo "   • JAVA_HOME:    $JAVA_HOME"
          echo "   • Run 'android-fhs' if you hit any Gradle/NDK ELF binary issues."
        '';
      };
    };
}
