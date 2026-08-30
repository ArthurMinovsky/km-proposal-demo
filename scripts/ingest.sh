#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[[ $# -eq 1 ]] || { echo "Usage: ./scripts/ingest.sh <file>" >&2; exit 2; }
command -v docker >/dev/null || { echo "Docker is required." >&2; exit 1; }
docker compose version >/dev/null || { echo "Docker Compose v2 is required." >&2; exit 1; }
[[ -f .env ]] || { echo "Run ./scripts/install.sh first." >&2; exit 1; }

INPUT="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$1")"
[[ -e "$INPUT" ]] || { echo "Path not found: $INPUT" >&2; exit 2; }

docker compose --profile tools build ingest
BASENAME="$(basename "$INPUT")"
docker compose --profile tools run --rm --no-deps \
  -v "$INPUT:/input/$BASENAME:ro" ingest "/input/$BASENAME"

echo
echo "Ingest complete."
echo "Original: source/imported/"
echo "Knowledge: knowledge/imported/"
echo "Search it immediately through the ACP agent using Vault Cortex MCP."
