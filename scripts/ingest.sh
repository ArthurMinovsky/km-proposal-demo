#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[[ $# -eq 1 ]] || { echo "Usage: ./scripts/ingest.sh <file>" >&2; exit 2; }
INPUT="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$1")"
[[ -e "$INPUT" ]] || { echo "Path not found: $INPUT" >&2; exit 2; }

USE_LOCAL=false
if [[ "${1:-}" == "--local" ]] || ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  USE_LOCAL=true
fi

if [[ "$USE_LOCAL" == "true" ]]; then
  echo "Docker unavailable or local mode selected. Running local Node.js ingest..."
  VAULT_PATH="${VAULT_HOST_PATH:-./runtime/vault}" node tools/ingest.mjs "$INPUT"
else
  [[ -f .env ]] || { echo "Run ./scripts/install.sh first." >&2; exit 1; }
  docker compose --profile tools build ingest
  BASENAME="$(basename "$INPUT")"
  docker compose --profile tools run --rm --no-deps \
    -v "$INPUT:/input/$BASENAME:ro" ingest "/input/$BASENAME"
fi

echo
echo "Ingest complete."
echo "Original: source/imported/"
echo "Knowledge: knowledge/imported/"
echo "Search it immediately through the ACP agent using Vault Cortex MCP."
