{ self, inputs, ... }: {
  flake.nixosModules.parazeeknovaMobile =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      android-fhs = pkgs.buildFHSEnv {
        name = "android-fhs";
        targetPkgs =
          pkgs: with pkgs; [
            jdk17
            gradle
            android-tools
            watchman
            eas-cli
            bundletool
            scrcpy
            ninja
            glibc
            glibc.dev
            zlib
            ncurses5
            libxml2
            openssl
            stdenv.cc.cc.lib
            libGL
            alsa-lib
            fontconfig
            freetype
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
      nixpkgs.config.android_sdk.accept_license = true;
      environment.systemPackages = with pkgs; [
        android-studio
        android-tools
        bundletool
        scrcpy
        usbutils
        jdk17
        gradle
        watchman
        eas-cli
        android-fhs
      ];

      environment.sessionVariables = {
        ANDROID_HOME = "$HOME/Android/Sdk";
        ANDROID_SDK_ROOT = "$HOME/Android/Sdk";
        JAVA_HOME = "${pkgs.jdk17.home}";
      };

      users.groups.adbusers = { };
      users.users.parazeeknova.extraGroups = [
        "adbusers"
        "kvm"
      ];

      boot.kernel.sysctl = {
        "fs.inotify.max_user_watches" = 524288;
        "fs.inotify.max_user_instances" = 8192;
      };

      programs.nix-ld.libraries = with pkgs; [
        libxml2
        ncurses5
      ];

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
