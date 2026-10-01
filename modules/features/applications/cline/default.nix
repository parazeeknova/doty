{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaCline =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cline = pkgs.stdenv.mkDerivation rec {
        pname = "cline";
        version = "3.0.67";

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/@cline/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
          sha256 = "1va19l47wph84ygcsqc87sk608llsinv1dwhjfqajw8aifn4x9xd";
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          makeWrapper
        ];

        buildInputs = with pkgs; [
          stdenv.cc.cc.lib
          glibc
        ];

        dontStrip = true;

        installPhase = ''
          mkdir -p $out/lib/cline $out/bin
          cp -r * $out/lib/cline/
          chmod +x $out/lib/cline/bin/cline
          ln -s $out/lib/cline/bin/cline $out/bin/cline
        '';
      };
    in
    {
      environment.systemPackages = [ cline ];
    };
}
