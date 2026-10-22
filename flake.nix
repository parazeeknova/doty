{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Local compatibility patch, used until this revision is published upstream.
    lennette-private.url = "path:/home/parazeeknova/Projects/lennette/packaging/hyprland";

    hyprland-preview-share-picker = {
      url = "git+https://github.com/WhySoBad/hyprland-preview-share-picker?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-scroll-overview = {
      url = "github:yayuuu/hyprland-scroll-overview/9a658551a962dd788017734bfb8b37c80d11d522";
      flake = false;
    };

    hyprglass = {
      url = "github:hyprnux/hyprglass/7c574b4c7aabc3364c7aae07584d896649179b18";
      flake = false;
    };

    hypr-dynamic-cursors = {
      url = "github:VirtCode/hypr-dynamic-cursors/2a8d0b735328d874a78ca93b2f201649f712a74a";
      flake = false;
    };

    hypr-edgehover = {
      url = "github:gfhdhytghd/hypr-edgehover/023bded40917630de7fd122ba45dba607930c206";
      flake = false;
    };

    hymission = {
      url = "github:gfhdhytghd/hymission/1d623faace3b5ff87ac5711847a9580461838bc4";
      flake = false;
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins/d2427d4d15b36df40468f5a58bbd67cdba19835d";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprland.follows = "lennette-private/hyprland";
    };
    vscode-insiders = {
      url = "github:auguwu/vscode-insiders-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:mic92/sops-nix";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ (inputs.import-tree ./modules) ];
      systems = [ "x86_64-linux" ];
      perSystem =
        { system, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };
        };
    };
}
