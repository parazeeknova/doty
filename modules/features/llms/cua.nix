{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaCua =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cua = pkgs.stdenv.mkDerivation rec {
        pname = "cua";
        version = "0.5.0";

        src = pkgs.fetchurl {
          url = "https://github.com/trycua/cua/releases/download/cua-sdk-v${version}/cua-cli-${version}-linux-x64.tar.gz";
          sha256 = "01hk00h3f5g4i3wh1aq6hdfz0ir0mkklc4r4ghwzl1i1cqazfyva";
        };

        sourceRoot = ".";
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];

        installPhase = ''
          install -m755 -D cua $out/bin/cua
        '';

        meta = {
          description = "Cua CLI - infrastructure framework for Computer-Use AI agents";
          homepage = "https://github.com/trycua/cua";
          platforms = [ "x86_64-linux" ];
          mainProgram = "cua";
        };
      };

      cua-driver = pkgs.stdenv.mkDerivation rec {
        pname = "cua-driver";
        version = "0.37.0";

        src = pkgs.fetchurl {
          url = "https://github.com/trycua/cua/releases/download/cua-driver-rs-v${version}/cua-driver-rs-${version}-linux-x86_64-binary.tar.gz";
          sha256 = "08snrnwq3zkkq9i7j8rahp4vx24miaw90b8ba5z20z6s21mkgb67";
        };

        sourceRoot = ".";
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = with pkgs; [
          libx11
          libxi
          libxkbcommon
          stdenv.cc.cc.lib
        ];

        installPhase = ''
          install -m755 -D cua-driver $out/bin/cua-driver
          if [ -f cua-cursor-theme ]; then
            install -m755 -D cua-cursor-theme $out/bin/cua-cursor-theme
          fi
          if [ -f libcua_driver_sdk.so ]; then
            install -m755 -D libcua_driver_sdk.so $out/lib/libcua_driver_sdk.so
          fi
        '';

        meta = {
          description = "Cua Driver - computer-use automation driver for AI agents";
          homepage = "https://github.com/trycua/cua";
          platforms = [ "x86_64-linux" ];
          mainProgram = "cua-driver";
        };
      };
    in
    {
      environment.systemPackages = [
        cua
        cua-driver
      ];

      environment.sessionVariables = {
        CUA_DRIVER_RS_ENABLE_WAYLAND = "1";
        HERMES_CUA_DRIVER_CMD = "${cua-driver}/bin/cua-driver";
      };
    };
}
