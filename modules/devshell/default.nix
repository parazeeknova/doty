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

        RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
      };
    };
}
