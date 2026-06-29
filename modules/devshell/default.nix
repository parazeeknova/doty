{ self, inputs, ... }: {
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        name = "doty-dev";

        nativeBuildInputs = with pkgs; [
          rustc
          cargo
          clippy
          rustfmt
          pkg-config
          openssl
          nixfmt
          qt6.qtdeclarative
          stylua
          gnumake
          git
          sops
          age
        ];

        shellHook = ''
          echo ""
          echo "  doty devshell"
          echo "  rust  : $(rustc --version 2>/dev/null | cut -d' ' -f2)"
          echo "  cargo : $(cargo --version 2>/dev/null | cut -d' ' -f2)"
          echo ""
        '';

        RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
      };
    };
}
