#!/usr/bin/env bash
# Bridges the local supermemory server (REST, localhost:6767) into MCP over stdio.
#
# The self-hosted supermemory binary exposes only a REST API (v4 + v3) and no
# MCP endpoint, so this wrapper adapts its OpenAPI spec into MCP tools.
#
# The API key is read from the environment at launch; DSH passes it in via the
# plugin's `env` block, which is required because the harness scrubs ambient
# names matching KEY|PASSWORD|SECRET|TOKEN from stdio children.
#
# The header value uses the bridge's own ${VAR} interpolation rather than being
# expanded by this shell, so the key stays out of argv and never appears in `ps`.
set -euo pipefail

if [ -z "${SUPERMEMORY_API_KEY:-}" ]; then
  if [ -f /run/secrets/supermemory-api-key ]; then
    SUPERMEMORY_API_KEY=$(cat /run/secrets/supermemory-api-key)
  elif [ -f "$HOME/.supermemory/api-key" ]; then
    SUPERMEMORY_API_KEY=$(cat "$HOME/.supermemory/api-key")
  fi
fi

: "${SUPERMEMORY_API_KEY:?SUPERMEMORY_API_KEY must be set in the environment or /run/secrets}"

SPEC="${SUPERMEMORY_OPENAPI_SPEC:-$HOME/.dsh/mcp/supermemory/openapi.json}"
BASE_URL="${SUPERMEMORY_BASE_URL:-http://localhost:6767}"

exec npx -y @ivotoby/openapi-mcp-server@1.16.1 \
  --transport stdio \
  --api-base-url "$BASE_URL" \
  --openapi-spec "$SPEC" \
  --name supermemory-local \
  --server-version 1.0.0 \
  --tools all \
  --headers 'Authorization:Bearer ${SUPERMEMORY_API_KEY}'