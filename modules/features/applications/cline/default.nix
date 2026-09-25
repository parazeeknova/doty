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
        version = "3.0.65";

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/@cline/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
          sha256 = "04qdj02c0vw0lfr3wmf4gvvqszh20gm4r8qdk35rzrvav76xqk5a";
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
