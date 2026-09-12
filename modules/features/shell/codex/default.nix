{ self, inputs, ... }:

{
  flake.nixosModules.parazeeknovaCodex =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      codexPkg = inputs.codex-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      home-manager.users.parazeeknova =
        { config, pkgs, ... }:
        {
          sops = {
            secrets.openrouter-api-key = { };
            secrets.merge-gateway-api-key = { };
            secrets.context7-api-key = { };
            secrets.github-token = { };

            templates."codex-config" = {
              content = ''
                model = "gpt-5.6-luna"
                model_reasoning_effort = "high"

                [notice]
                hide_rate_limit_model_nudge = true

                [features]
                hooks = true
                memories = true

                [projects."/home/parazeeknova/Repository/sw/singularityworks"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Projects/verso"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Projects/ho"]
                trust_level = "trusted"

                [projects."/home/parazeeknova"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Documents/Codex/2026-09-08/hatch-pet-home-parazeeknova-codex-skills"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Documents/Codex/2026-09-08/hatch-pet-home-parazeeknova-codex-skills-2"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Documents/Codex/2026-09-08/hatch-pet-home-parazeeknova-codex-skills-3"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Documents/Codex/2026-09-08/hatch-pet-home-parazeeknova-codex-skills-4"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Documents/Codex/2026-09-08/hatch-pet-home-parazeeknova-codex-skills-5"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Documents/Codex/2026-09-08/hatch-pet-home-parazeeknova-codex-skills-6"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Documents/Codex/2026-09-08/hatch-pet-home-parazeeknova-codex-skills-7"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Documents/Codex/2026-09-08/hatch-pet-home-parazeeknova-codex-skills-8"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Documents/Codex/2026-09-08/yoo"]
                trust_level = "trusted"

                [projects."/home/parazeeknova/Repository/asm/social"]
                trust_level = "trusted"

                [tui.model_availability_nux]
                "gpt-5.5" = 2
                "gpt-5.6-sol" = 2

                [mcp_servers.context7]
                url = "https://mcp.context7.com/mcp"

                [mcp_servers.context7.http_headers]
                CONTEXT7_API_KEY = "${config.sops.placeholder.context7-api-key}"

                [mcp_servers.github]
                command = "npx"
                args = [
                    "-y",
                    "@modelcontextprotocol/server-github",
                ]

                [mcp_servers.github.env]
                GITHUB_PERSONAL_ACCESS_TOKEN = "${config.sops.placeholder.github-token}"

                [mcp_servers.filesystem]
                command = "npx"
                args = [
                    "-y",
                    "@modelcontextprotocol/server-filesystem",
                    "/home/parazeeknova/doty",
                    "/home/parazeeknova/Repository",
                    "/home/parazeeknova/Projects",
                    "/home/parazeeknova",
                ]

                [mcp_servers.playwright]
                command = "npx"
                args = [
                    "-y",
                    "@playwright/mcp",
                ]

                [mcp_servers.chrome-devtools]
                command = "npx"
                args = [
                    "-y",
                    "chrome-devtools-mcp@latest",
                    "--autoConnect",
                ]

                [mcp_servers.firecrawl]
                command = "bunx"
                args = ["firecrawl-mcp"]

                [mcp_servers.firecrawl.env]
                FIRECRAWL_API_URL = "http://127.0.0.1:48002"

                [mcp_servers.hindsight]
                url = "http://127.0.0.1:48888/mcp/default"

                [mcp_servers.camofox]
                command = "npx"
                args = [
                    "-y",
                    "camofox-mcp@latest",
                ]

                [mcp_servers.camofox.env]
                CAMOFOX_URL = "http://127.0.0.1:49377"

                [mcp_servers.node_repl]
                args = []
                command = "${codexPkg}/opt/codex-desktop/resources/cua_node/bin/node_repl"
                startup_timeout_sec = 120

                [mcp_servers.node_repl.env]
                NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS = "1000"
                NODE_REPL_NODE_MODULE_DIRS = "${codexPkg}/opt/codex-desktop/resources/cua_node/lib/node_modules"
                NODE_REPL_NODE_PATH = "${codexPkg}/opt/codex-desktop/resources/cua_node/bin/node"
                NODE_REPL_TRUSTED_CODE_PATHS = "/home/parazeeknova/.codex:${codexPkg}/opt/codex-desktop/resources/cua_node/lib/node_modules"
                CODEX_HOME = "/home/parazeeknova/.codex"
                BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab"
                BROWSER_USE_TINYSKY_ENABLED = "1"
                NODE_REPL_INSTRUCTIONS_USE_CASE_BROWSER = ""
                NODE_REPL_INSTRUCTIONS_USE_CASE_CHROME = ""
                BROWSER_USE_CODEX_APP_BUILD_FLAVOR = "prod"
                BROWSER_USE_CODEX_APP_VERSION = "26.901.51231"
                NODE_REPL_TRUSTED_SERVICES = '{"browser":"/home/parazeeknova/.codex/plugins/cache/openai-bundled/browser/26.901.51231/scripts/browser-service.mjs"}'
                CODEX_CLI_PATH = "${codexPkg}/opt/codex-desktop/resources/codex"

                [mcp_servers.tldraw]
                url = "https://tldraw-mcp-app.tldraw.workers.dev/mcp"

                [hooks.state."/home/parazeeknova/.codex/hooks.json:session_start:0:0"]
                trusted_hash = "sha256:65c200b17729361a95bcd97e8460bcb29e6995c0b58aa60e8f7301a63a52898e"

                [desktop]
                followUpQueueMode = "steer"
                conversationDetailMode = "STEPS_COMMANDS"
                ambient-suggestions-enabled = false
                localeOverride = "en-US"
                appearanceTheme = "dark"
                appearanceDarkCodeThemeId = "gruvbox"
                usePointerCursors = true
                sansFontSize = 12
                codeFontSize = 10
                selected-avatar-id = "custom:columbinya-2"
                external-agent-import-sync-item-types = "all"
                external-agent-import-sync-enabled = true

                [desktop.appearanceDarkChromeTheme]
                accent = "#458588"
                accentSource = "custom"
                contrast = 70
                ink = "#ebdbb2"
                opaqueWindows = false
                surface = "#282828"

                [desktop.appearanceDarkChromeTheme.fonts]

                [desktop.appearanceDarkChromeTheme.semanticColors]
                diffAdded = "#ebdbb2"
                diffRemoved = "#cc241d"
                skill = "#b16286"

                [marketplaces.openai-bundled]
                source_type = "local"
                source = "/home/parazeeknova/.codex/.tmp/bundled-marketplaces/openai-bundled"

                [marketplaces.claude-plugins-official]
                source_type = "git"
                source = "https://github.com/anthropics/claude-plugins-official.git"

                [plugins."codex-app-tools@openai-bundled"]
                enabled = true

                [plugins."browser@openai-bundled"]
                enabled = true

                [plugins."unified-computer-use@openai-bundled"]
                enabled = true

                [plugins."visualize@openai-bundled"]
                enabled = true

                [plugins."chrome@openai-bundled"]
                enabled = true

                [plugins."typescript-lsp@claude-plugins-official"]
                enabled = true

                [memories]
                generate_memories = true
                use_memories = true

                [shell_environment_policy]
                inherit = "core"

                [shell_environment_policy.set]
                ENABLE_LSP_TOOL = "1"
                MERGE_GATEWAY_API_KEY = "${config.sops.placeholder.merge-gateway-api-key}"
                ANTHROPIC_BASE_URL = "https://api-gateway.merge.dev/v1/anthropic"
                ANTHROPIC_AUTH_TOKEN = "${config.sops.placeholder.merge-gateway-api-key}"
                ANTHROPIC_API_KEY = ""
                ANTHROPIC_MODEL = "zai/glm-5.3-flash"
                ANTHROPIC_CUSTOM_MODEL = "zai/glm-5.3-flash"
                ANTHROPIC_CUSTOM_MODEL_OPTION = "zai/glm-5.3-flash"
                ANTHROPIC_CUSTOM_MODEL_OPTION_NAME = "zai/glm-5.3-flash"
                CLAUDE_CODE_CUSTOM_MODEL = "zai/glm-5.3-flash"
                ANTHROPIC_DEFAULT_OPUS_MODEL = "zai/glm-5.3-flash"
                ANTHROPIC_DEFAULT_SONNET_MODEL = "zai/glm-5.3-flash"
                ANTHROPIC_DEFAULT_HAIKU_MODEL = "zai/glm-5.3-flash"
                ANTHROPIC_DEFAULT_FABLE_MODEL = "zai/glm-5.3-flash"
                CLAUDE_CODE_SUBAGENT_MODEL = "zai/glm-5.3-flash"
                CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1"
                CLAUDE_CODE_EFFORT_LEVEL = "max"
                CLAUDE_CODE_MAX_CONTEXT_TOKENS = "1000000"
                CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT = "1"
                OPENROUTER_API_KEY = "${config.sops.placeholder.openrouter-api-key}"
                CONTEXT7_API_KEY = "${config.sops.placeholder.context7-api-key}"
                GITHUB_PERSONAL_ACCESS_TOKEN = "${config.sops.placeholder.github-token}"
              '';
              path = "${config.home.homeDirectory}/.codex/config.toml";
            };
          };
        };
    };
}
