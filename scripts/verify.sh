#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[1/6] shell syntax"
bash -n scripts/install.sh scripts/ingest.sh scripts/uninstall.sh scripts/status.sh scripts/verify.sh

echo "[2/6] required deliverables"
test -f docker-compose.yml
test -f Dockerfile.ingest
test -f tools/ingest.mjs
test -f skill/km-management/SKILL.md
test -f README.md
test -f demo-imports/project-facts.csv

echo "[3/6] simplified demo workflow"
grep -q 'There is no review/promotion gate in this demo' skill/km-management/SKILL.md
grep -q './scripts/ingest.sh <file>' skill/km-management/SKILL.md
! grep -q 'explicit promotion' skill/km-management/SKILL.md

echo "[4/6] uninstall ownership guard"
grep -q '.km-demo-owned' scripts/uninstall.sh
grep -q 'sentinel is absent' scripts/uninstall.sh
grep -q 'km-proposal-demo-ingest' scripts/uninstall.sh

echo "[5/6] compose parse"
command -v docker >/dev/null || { echo "Docker is required for verification." >&2; exit 1; }
docker compose version >/dev/null
cp -n .env.example .env || true
python3 - <<'PY'
from pathlib import Path
p=Path('.env')
s=p.read_text()
if 'MCP_AUTH_TOKEN=CHANGE_ME' in s:
    p.write_text(s.replace('MCP_AUTH_TOKEN=CHANGE_ME','MCP_AUTH_TOKEN=verify-only-token'))
PY
docker compose --profile obsidian-sync --profile tools config >/dev/null

echo "[6/6] ingest image build"
docker compose --profile tools build ingest

echo "Verification passed."
