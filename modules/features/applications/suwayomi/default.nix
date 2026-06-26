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
          version = "2.2.2100";
          src = pkgs.fetchurl {
            url = "https://github.com/Suwayomi/Suwayomi-Server/releases/download/v${version}/Suwayomi-Server-v${version}.jar";
            hash = "sha256-PIEypDv6m5WbDI/b3PmqAb2AkEf/T7waSq4OtxMx8F4=";
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
            extensionRepos = [
              "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
            ];
            localSourcePath = "/home/parazeeknova/Manga";
            systemTrayEnabled = false;
          };
        };
      };
    };
}
