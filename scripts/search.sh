#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -eq 0 ]]; then
  echo "Usage: ./scripts/search.sh <query> [options]"
  echo "Example: ./scripts/search.sh 'Retrieval order'"
  echo "         ./scripts/search.sh --id DOC-C53E"
  exit 1
fi

node tools/search.mjs "$@"
