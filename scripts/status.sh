#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== Compose =="
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker compose --profile obsidian-sync --profile tools ps || true
else
  echo "Docker is unavailable or daemon is not running; reporting local filesystem status."
fi

echo
echo "== MCP health =="
PORT="$(awk -F= '$1=="MCP_PORT"{print $2}' .env 2>/dev/null | tail -1)"
PORT="${PORT:-9705}"
curl -fsS "http://127.0.0.1:${PORT}/healthz" || true
echo

echo
echo "== Local demo paths =="
for p in runtime/vault runtime/mcp-data runtime/obsidian-config; do
  [[ -e "$p" ]] && du -sh "$p" || echo "$p: absent"
done

echo
echo "== Imported documents =="
if [[ -d runtime/vault/.km/ingest ]]; then
  find runtime/vault/.km/ingest -type f -name 'DOC-*.json' | wc -l | tr -d ' '
else
  echo "0"
fi
