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
command -v curl >/dev/null || { echo "curl is required." >&2; exit 1; }
command -v python3 >/dev/null || { echo "Python 3 is required." >&2; exit 1; }

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

TOKEN="$(awk -F= '$1=="MCP_AUTH_TOKEN"{print $2}' .env | tail -1)"
if [[ -z "$TOKEN" || "$TOKEN" == "CHANGE_ME" ]]; then
  TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  python3 - "$TOKEN" <<'PY'
from pathlib import Path
import re
import sys
p = Path('.env')
s = p.read_text()
s, replacements = re.subn(
    r'^MCP_AUTH_TOKEN=.*$',
    'MCP_AUTH_TOKEN=' + sys.argv[1],
    s,
    flags=re.MULTILINE,
)
if replacements != 1:
    raise SystemExit('Expected exactly one MCP_AUTH_TOKEN entry in .env')
p.write_text(s)
PY
  echo "Generated an MCP bearer token in .env."
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
  FILE_PORT="$(awk -F= '$1=="MCP_PORT"{print $2}' .env | tail -1)"
  PORT="${MCP_PORT:-${FILE_PORT:-9705}}"
  if [[ "$WITH_SYNC" -eq 1 ]]; then
    docker compose --profile obsidian-sync up -d
  else
    docker compose up -d mcp
  fi

  for attempt in {1..30}; do
    if curl -fsS "http://127.0.0.1:${PORT}/healthz" >/dev/null 2>&1; then
      break
    fi
    if ! docker compose ps --status running --services | grep -qx 'mcp'; then
      echo "Vault Cortex exited before becoming healthy." >&2
      docker compose logs --no-color --tail=100 mcp >&2 || true
      exit 1
    fi
    if [[ "$attempt" -eq 30 ]]; then
      echo "Vault Cortex did not become healthy within 60 seconds." >&2
      docker compose logs --no-color --tail=100 mcp >&2 || true
      exit 1
    fi
    sleep 2
  done
  
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
  echo
  echo "[2] Claude Desktop / Claude Code (claude_desktop_config.json / mcp.json):"
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
  echo
  echo "[3] Codex (~/.codex/config.toml):"
  cat <<EOF
[mcp_servers.km_vault]
url = "http://localhost:${PORT}/mcp"
headers = { "Authorization" = "Bearer ${TOKEN}" }
EOF
  echo "============================================================"
else
  echo "Configuration validated and ingest image built; persistent containers not started."
fi
