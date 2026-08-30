#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[1/8] shell syntax"
bash -n scripts/install.sh scripts/ingest.sh scripts/uninstall.sh scripts/status.sh scripts/verify.sh

echo "[2/8] required deliverables"
test -f docker-compose.yml
test -f Dockerfile.ingest
test -f tools/ingest.mjs
test -f skill/km-management/SKILL.md
test -f README.md
test -f demo-imports/project-facts.csv

echo "[3/8] simplified demo workflow"
grep -q 'There is no review/promotion gate in this demo' skill/km-management/SKILL.md
grep -q './scripts/ingest.sh <file>' skill/km-management/SKILL.md
! grep -q 'explicit promotion' skill/km-management/SKILL.md

echo "[4/8] MCP authentication install contract"
grep -qx 'MCP_AUTH_TOKEN=CHANGE_ME' .env.example
grep -q 'secrets.token_hex(32)' scripts/install.sh
grep -q 'Generated an MCP bearer token in .env.' scripts/install.sh
grep -q 'Vault Cortex did not become healthy' scripts/install.sh
grep -q 'Python 3 is required.' scripts/install.sh

echo "[5/8] fresh installer token regression"
TEST_ROOT="$(mktemp -d)"
cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT
tar --exclude='.git' --exclude='.env' --exclude='runtime' --exclude='.demo-install-state' -cf - . | tar -xf - -C "$TEST_ROOT"
(
  cd "$TEST_ROOT"
  COMPOSE_PROJECT_NAME=km-proposal-demo-verify ./scripts/install.sh --no-start >/dev/null
  TOKEN="$(awk -F= '$1=="MCP_AUTH_TOKEN"{print $2}' .env | tail -1)"
  [[ "$TOKEN" =~ ^[0-9a-f]{64}$ ]]
  docker compose config | grep -Eq 'MCP_AUTH_TOKEN: [0-9a-f]{64}'
)

echo "[6/8] uninstall ownership guard"
grep -q '.km-demo-owned' scripts/uninstall.sh
grep -q 'sentinel is absent' scripts/uninstall.sh
grep -q 'km-proposal-demo-ingest' scripts/uninstall.sh

echo "[7/8] compose parse"
command -v docker >/dev/null || { echo "Docker is required for verification." >&2; exit 1; }
docker compose version >/dev/null
cp -n .env.example .env || true
docker compose --profile obsidian-sync --profile tools config >/dev/null

echo "[8/8] ingest image build"
docker compose --profile tools build ingest

echo "Verification passed."
