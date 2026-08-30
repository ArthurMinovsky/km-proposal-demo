#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

USE_LOCAL=false
INPUT_PATH=""

for arg in "$@"; do
  case "$arg" in
    --local) USE_LOCAL=true ;;
    -h|--help)
      echo "Usage: ./scripts/ingest.sh [--local] <file_or_directory>"
      exit 0
      ;;
    *)
      if [[ -z "$INPUT_PATH" ]]; then
        INPUT_PATH="$arg"
      else
        echo "Unexpected argument: $arg" >&2
        exit 2
      fi
      ;;
  esac
done

[[ -n "$INPUT_PATH" ]] || { echo "Usage: ./scripts/ingest.sh [--local] <file_or_directory>" >&2; exit 2; }

INPUT="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$INPUT_PATH")"
[[ -e "$INPUT" ]] || { echo "Path not found: $INPUT" >&2; exit 2; }

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
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
