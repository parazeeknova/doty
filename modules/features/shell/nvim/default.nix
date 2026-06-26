{ self, inputs, ... }: {

  flake.nixosModules.parazeeknovaNvim =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home-manager.users.parazeeknova =
        { config, pkgs, ... }:
        {
          imports = [
            inputs.nvf.homeManagerModules.default
          ];

          programs.nvf = {
            enable = true;
            settings = {
              vim = {
                viAlias = false;
                vimAlias = false;

                # General Options
                options = {
                  number = true;
                  relativenumber = true;
                  shiftwidth = 2;
                  tabstop = 2;
                  smartindent = true;
                  expandtab = true;
                  clipboard = "unnamedplus";
                };

                # Theme (Catppuccin Mocha with Transparency)
                theme = {
                  enable = true;
                  name = "catppuccin";
                  style = "mocha";
                  transparent = true;
                };

                # Binds (which-key shortcut helper)
                binds = {
                  whichKey.enable = true;
                };

                # Statusline / Bufferline
                statusline.lualine = {
                  enable = true;
                  theme = "auto";
                };
                tabline.nvimBufferline.enable = true;

                # Visuals
                visuals = {
                  nvim-web-devicons.enable = true;
                  indent-blankline.enable = true;
                };

                # Explorer & Dashboard & Utilities
                filetree.neo-tree.enable = true;
                dashboard.alpha.enable = true;
                terminal.toggleterm.enable = true;

                # Git integration
                git = {
                  enable = true;
                  gitsigns.enable = true;
                };

                # Search & Navigation
                telescope.enable = true;

                # Treesitter (Syntax Highlighting)
                treesitter = {
                  enable = true;
                  autotagHtml = true;
                };

                # Completion
                autocomplete.nvim-cmp = {
                  enable = true;
                };

                # Formatter (conform-nvim)
                formatter = {
                  conform-nvim.enable = true;
                };

                # LSP
                lsp = {
                  enable = true;
                  formatOnSave = true;
                  lightbulb.enable = true;
                  trouble.enable = true;
                };

                # Language Support
                languages = {
                  enableTreesitter = true;
                  enableLSP = true;
                  enableFormat = true;

                  nix.enable = true;
                  markdown.enable = true;
                  html.enable = true;
                  css.enable = true;
                  rust.enable = true;
                  python.enable = true;
                  typescript.enable = true;
                  lua.enable = true;
                  bash.enable = true;
                  clang.enable = true;
                  go.enable = true;
                  make.enable = true;
                  json.enable = true;
                  toml.enable = true;
                  yaml.enable = true;
                };
              };
            };
          };
        };
    };
}
