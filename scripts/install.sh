#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WITH_SYNC=0
NO_START=0
for arg in "$@"; do
  case "$arg" in
    --with-obsidian-sync) WITH_SYNC=1 ;;
    --no-start) NO_START=1 ;;
    -h|--help) echo "Usage: ./scripts/install.sh [--with-obsidian-sync] [--no-start]"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v docker >/dev/null || { echo "Docker is required." >&2; exit 1; }
docker compose version >/dev/null || { echo "Docker Compose v2 is required." >&2; exit 1; }

if [[ ! -f .env ]]; then
  cp .env.example .env
  python3 - "$(id -u)" "$(id -g)" <<'PY'
from pathlib import Path
import sys
p=Path('.env')
s=p.read_text().replace('PUID=1000','PUID='+sys.argv[1]).replace('PGID=1000','PGID='+sys.argv[2])
p.write_text(s)
PY
  echo "Created .env from .env.example."
else
  echo "Using existing .env; it was not overwritten."
fi

mkdir -p runtime/mcp-data runtime/obsidian-config
if [[ ! -e runtime/vault/.km-demo-owned ]]; then
  if [[ -d runtime/vault ]] && find runtime/vault -mindepth 1 -maxdepth 1 | grep -q .; then
    echo "runtime/vault already contains data; leaving it untouched."
  else
    mkdir -p runtime/vault
    cp -R demo-vault/. runtime/vault/
    printf 'created_by=km-proposal-demo\ncreated_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > runtime/vault/.km-demo-owned
    echo "Created disposable demo vault under runtime/vault."
  fi
fi

printf 'project_root=%s\ncompose_project=km-proposal-demo\n' "$ROOT" > .demo-install-state
docker compose config >/dev/null
docker compose --profile tools build ingest

if [[ "$WITH_SYNC" -eq 1 ]]; then
  source .env
  [[ -n "${OBSIDIAN_AUTH_TOKEN:-}" ]] || { echo "OBSIDIAN_AUTH_TOKEN is empty in .env" >&2; exit 3; }
  [[ -n "${VAULT_NAME:-}" ]] || { echo "VAULT_NAME is empty in .env" >&2; exit 3; }
  docker compose --profile obsidian-sync config >/dev/null
fi

if [[ "$NO_START" -eq 0 ]]; then
  if [[ "$WITH_SYNC" -eq 1 ]]; then
    docker compose --profile obsidian-sync up -d
  else
    docker compose up -d mcp
  fi
  PORT="$(awk -F= '$1=="MCP_PORT"{print $2}' .env | tail -1)"
  PORT="${PORT:-9705}"
  TOKEN="$(awk -F= '$1=="MCP_AUTH_TOKEN"{print $2}' .env 2>/dev/null | tail -1)"
  
  echo
  echo "============================================================"
  echo "  KM Proposal Demo MCP Server is Ready!"
  echo "============================================================"
  echo "Endpoint: http://localhost:${PORT}/mcp"
  echo "Health:   http://localhost:${PORT}/healthz"
  echo "Ingest:   ./scripts/ingest.sh <file_or_directory>"
  echo
  echo "--- MCP Configuration Templates for Agent CLIs ---"
  echo
  echo "[1] OpenCode (~/.config/opencode/opencode.json):"
  if [[ -n "$TOKEN" ]]; then
    cat <<EOF
"mcp": {
  "km-vault": {
    "type": "remote",
    "url": "http://localhost:${PORT}/mcp",
    "headers": {
      "Authorization": "Bearer ${TOKEN}"
    },
    "enabled": true
  }
}
EOF
  else
    cat <<EOF
"mcp": {
  "km-vault": {
    "type": "remote",
    "url": "http://localhost:${PORT}/mcp",
    "enabled": true
  }
}
EOF
  fi
  echo
  echo "[2] Claude Desktop / Claude Code (claude_desktop_config.json / mcp.json):"
  if [[ -n "$TOKEN" ]]; then
    cat <<EOF
"mcpServers": {
  "km-vault": {
    "url": "http://localhost:${PORT}/mcp",
    "headers": {
      "Authorization": "Bearer ${TOKEN}"
    }
  }
}
EOF
  else
    cat <<EOF
"mcpServers": {
  "km-vault": {
    "url": "http://localhost:${PORT}/mcp"
  }
}
EOF
  fi
  echo
  echo "[3] Codex (~/.codex/config.toml):"
  if [[ -n "$TOKEN" ]]; then
    cat <<EOF
[mcp_servers.km_vault]
url = "http://localhost:${PORT}/mcp"
headers = { "Authorization" = "Bearer ${TOKEN}" }
EOF
  else
    cat <<EOF
[mcp_servers.km_vault]
url = "http://localhost:${PORT}/mcp"
EOF
  fi
  echo "============================================================"
else
  echo "Configuration validated and ingest image built; persistent containers not started."
fi
