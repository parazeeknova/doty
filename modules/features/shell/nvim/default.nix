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
                viAlias = true;
                vimAlias = true;

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

                # Theme (Dynamic Gruvbox using Matugen Colors)
                theme.enable = false;

                extraPlugins = {
                  gruvbox-nvim = {
                    package = pkgs.vimPlugins.gruvbox-nvim;
                  };
                };

                luaConfigRC.theme = ''
                  local home = os.getenv("HOME")
                  local colors_file = home .. "/.cache/quickshell/colors.json"
                  local f = io.open(colors_file, "r")
                  if f then
                    local content = f:read("*all")
                    f:close()
                    local ok, colors = pcall(vim.json.decode, content)
                    if ok and colors then
                      require("gruvbox").setup({
                        terminal_colors = true,
                        undercurl = true,
                        underline = true,
                        bold = true,
                        italic = {
                          strings = true,
                          emphasis = true,
                          comments = true,
                          operators = false,
                          folds = true
                        },
                        strikethrough = true,
                        invert_selection = false,
                        invert_signs = false,
                        invert_tabline = false,
                        inverse = true,
                        contrast = "hard",
                        palette_overrides = {
                          dark0_hard = colors.bg,
                          dark0 = colors.bg_dark,
                          dark1 = colors.bg_light,
                          dark2 = colors.bg_light,
                          dark3 = colors.bg_light,
                          dark4 = colors.bg_light,
                          light0 = colors.fg,
                          light1 = colors.fg_light,
                          light2 = colors.fg_light,
                          light3 = colors.fg_light,
                          light4 = colors.fg_light,
                          bright_red = colors.error,
                          bright_green = colors.accent,
                          bright_yellow = colors.tertiary,
                          bright_blue = colors.accent,
                          bright_purple = colors.secondary,
                          bright_aqua = colors.secondary,
                          bright_orange = colors.tertiary,
                          neutral_red = colors.error,
                          neutral_green = colors.accent,
                          neutral_yellow = colors.tertiary,
                          neutral_blue = colors.accent,
                          neutral_purple = colors.secondary,
                          neutral_aqua = colors.secondary,
                          neutral_orange = colors.tertiary,
                        },
                        overrides = {
                          NormalFloat = { bg = "NONE" },
                          FloatBorder = { bg = "NONE" },
                          FloatTitle = { bg = "NONE" },
                        },
                        dim_inactive = true,
                        transparent_mode = true
                      })
                      vim.cmd("colorscheme gruvbox")
                    else
                      require("gruvbox").setup({
                        contrast = "hard",
                        transparent_mode = true,
                      })
                      vim.cmd("colorscheme gruvbox")
                    end
                  else
                    require("gruvbox").setup({
                      contrast = "hard",
                      transparent_mode = true,
                    })
                    vim.cmd("colorscheme gruvbox")
                  end
                '';

                # Statusline / Bufferline
                statusline.lualine = {
                  enable = true;
                  theme = "gruvbox";
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

                # LSP
                lsp = {
                  enable = true;
                  formatOnSave = true;
                  lightbulb.enable = true;
                };

                # Language Support
                languages = {
                  enableTreesitter = true;
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
