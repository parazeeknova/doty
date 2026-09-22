{ self, inputs, ... }:

let
  repo = "/home/parazeeknova/doty";
  claudeDir = "${repo}/modules/features/shell/claude";
in
{
  flake.nixosModules.parazeeknovaClaude =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home-manager.users.parazeeknova =
        { config, pkgs, ... }:
        let
          inherit (config.lib.file) mkOutOfStoreSymlink;
        in
        {
          sops = {
            secrets.anthropic-api-key = { };
            secrets.openrouter-api-key = { };
            secrets.context7-api-key = { };
            secrets.github-token = { };

            templates."claude-settings" = {
              content = ''
                {
                  "theme": "matugen",
                  "permissions": {
                    "defaultMode": "bypassPermissions"
                  },
                  "enabledPlugins": {
                    "typescript-lsp@claude-plugins-official": true
                  },
                  "env": {
                    "ENABLE_LSP_TOOL": "1",
                    "CLAUDE_CODE_EFFORT_LEVEL": "high",
                    "ANTHROPIC_API_KEY": "${config.sops.placeholder.anthropic-api-key}",
                    "OPENROUTER_API_KEY": "${config.sops.placeholder.openrouter-api-key}",
                    "CONTEXT7_API_KEY": "${config.sops.placeholder.context7-api-key}",
                    "GITHUB_PERSONAL_ACCESS_TOKEN": "${config.sops.placeholder.github-token}"
                  }
                }
              '';
              path = "${config.home.homeDirectory}/.claude/settings.json";
            };

            templates."claude-mcp" = {
              content = ''
                {
                  "mcpServers": {
                    "context7": {
                      "type": "http",
                      "url": "https://mcp.context7.com/mcp",
                      "headers": {
                        "CONTEXT7_API_KEY": "${config.sops.placeholder.context7-api-key}"
                      }
                    },
                    "github": {
                      "type": "stdio",
                      "command": "npx",
                      "args": [
                        "-y",
                        "@modelcontextprotocol/server-github"
                      ],
                      "env": {
                        "GITHUB_PERSONAL_ACCESS_TOKEN": "${config.sops.placeholder.github-token}"
                      }
                    },
                    "filesystem": {
                      "type": "stdio",
                      "command": "npx",
                      "args": [
                        "-y",
                        "@modelcontextprotocol/server-filesystem",
                        "/home/parazeeknova/doty",
                        "/home/parazeeknova/Repository",
                        "/home/parazeeknova/Projects",
                        "/home/parazeeknova"
                      ]
                    },
                    "playwright": {
                      "type": "stdio",
                      "command": "npx",
                      "args": [
                        "-y",
                        "@playwright/mcp"
                      ]
                    },
                    "chrome-devtools": {
                      "type": "stdio",
                      "command": "npx",
                      "args": [
                        "-y",
                        "chrome-devtools-mcp@latest",
                        "--autoConnect"
                      ]
                    },
                    "firecrawl": {
                      "type": "stdio",
                      "command": "bunx",
                      "args": [
                        "firecrawl-mcp"
                      ],
                      "env": {
                        "FIRECRAWL_API_URL": "http://127.0.0.1:48002"
                      }
                    },
                    "hindsight": {
                      "type": "http",
                      "url": "http://127.0.0.1:48888/mcp/default"
                    },
                    "camofox": {
                      "type": "stdio",
                      "command": "npx",
                      "args": [
                        "-y",
                        "camofox-mcp@latest"
                      ],
                      "env": {
                        "CAMOFOX_URL": "http://127.0.0.1:49377"
                      }
                    }
                  }
                }
              '';
            };
          };

          home = {
            file = {
              ".claude/themes/matugen.json" = {
                source = mkOutOfStoreSymlink "${claudeDir}/themes/matugen.json";
                force = true;
              };
              ".claude/themes/matugen.json.template" = {
                source = mkOutOfStoreSymlink "${claudeDir}/themes/matugen.json.template";
                force = true;
              };
            };

            activation.syncClaudeMcp = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              if [ -f "${config.sops.templates."claude-mcp".path}" ]; then
                ${pkgs.python3}/bin/python3 - << 'EOF'
              import json, os

              claude_json_path = os.path.expanduser("~/.claude.json")
              mcp_template_path = "${config.sops.templates."claude-mcp".path}"

              try:
                  with open(mcp_template_path, "r") as f:
                      template_data = json.load(f)

                  claude_data = {}
                  if os.path.exists(claude_json_path):
                      with open(claude_json_path, "r") as f:
                          claude_data = json.load(f)

                  claude_data["mcpServers"] = template_data.get("mcpServers", {})

                  with open(claude_json_path, "w") as f:
                      json.dump(claude_data, f, indent=2)
              except Exception as e:
                  print(f"Failed to sync claude MCP servers: {e}")
              EOF
              fi
            '';
          };
        };
    };
}
