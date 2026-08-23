{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaSuwayomi =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      # -- Suwayomi Server (Tachiyomi for Desktop) --
      services.suwayomi-server = {
        enable = true;
        package = pkgs.suwayomi-server.overrideAttrs (oldAttrs: rec {
          version = "2.3.2243";
          src = pkgs.fetchurl {
            url = "https://github.com/Suwayomi/Suwayomi-Server/releases/download/v${version}/Suwayomi-Server-v${version}.jar";
            hash = "sha256-ghFBsy4XDUoC08vf7Vd+2PB70iOD/19BMuu1rkDpjdU=";
          };
        });
        user = "parazeeknova";
        group = "users";
        dataDir = "/home/parazeeknova";
        openFirewall = false;
        settings = {
          server = {
            ip = "127.0.0.1";
            port = 29045;
            basicAuthEnabled = false;
            basicAuthUsername = "";
            basicAuthPasswordFile = null;
            downloadAsCbz = true;
            extensionStores = [
              "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
            ];
            localSourcePath = "/home/parazeeknova/Manga";
            systemTrayEnabled = false;
          };
        };
      };
    };
}
