#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PURGE=0
REMOVE_IMAGES=0
REMOVE_ENV=0
for arg in "$@"; do
  case "$arg" in
    --purge-demo-data) PURGE=1 ;;
    --remove-images) REMOVE_IMAGES=1 ;;
    --remove-env) REMOVE_ENV=1 ;;
    --restore-all) PURGE=1; REMOVE_IMAGES=1; REMOVE_ENV=1 ;;
    -h|--help)
      echo "Usage: ./scripts/uninstall.sh [--purge-demo-data] [--remove-images] [--remove-env] [--restore-all]"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "Stopping and removing demo Docker containers and networks..."
  docker compose --profile obsidian-sync --profile tools down --volumes --remove-orphans 2>/dev/null || true
  
  # Ensure any lingering project containers are stopped and removed
  DEMO_CONTAINERS="$(docker ps -aq --filter "label=com.docker.compose.project=km-proposal-demo" 2>/dev/null || true)"
  if [[ -n "$DEMO_CONTAINERS" ]]; then
    docker rm -f $DEMO_CONTAINERS 2>/dev/null || true
  fi
else
  echo "Docker daemon is unreachable or socket permission denied; skipping container cleanup."
fi

if [[ "$PURGE" -eq 1 ]]; then
  if [[ -f runtime/vault/.km-demo-owned ]]; then
    rm -rf runtime/vault
    echo "Removed demo-owned runtime/vault, including imported/generated knowledge."
  elif [[ -e runtime/vault ]]; then
    echo "Kept runtime/vault because the demo ownership sentinel is absent."
  fi
  rm -rf runtime/mcp-data runtime/obsidian-config
  rmdir runtime 2>/dev/null || true
  echo "Removed project-local MCP/Obsidian runtime data."
else
  echo "Runtime data kept. Use --purge-demo-data to delete demo-owned runtime data."
fi

if [[ "$REMOVE_IMAGES" -eq 1 ]] && command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  VC_TAG="latest"
  OS_TAG="latest"
  if [[ -f .env ]]; then
    VC_TAG="$(awk -F= '$1=="VAULT_CORTEX_TAG"{print $2}' .env 2>/dev/null | tail -1)"
    OS_TAG="$(awk -F= '$1=="OBSIDIAN_SERVER_TAG"{print $2}' .env 2>/dev/null | tail -1)"
  fi
  
  # Remove all demo-related ingest images (e.g. km-proposal-demo-ingest:latest, km-proposal-demo-verify-ingest)
  DEMO_INGEST_IMAGES="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^km-proposal-demo.*ingest' || true)"
  if [[ -n "$DEMO_INGEST_IMAGES" ]]; then
    docker image rm -f $DEMO_INGEST_IMAGES 2>/dev/null || true
  else
    docker image rm -f "km-proposal-demo-ingest:latest" 2>/dev/null || true
  fi

  docker image rm -f "ghcr.io/aliasunder/vault-cortex:${VC_TAG:-latest}" 2>/dev/null || true
  docker image rm -f "ghcr.io/belphemur/obsidian-headless-sync-docker:${OS_TAG:-latest}" 2>/dev/null || true
  echo "Attempted demo image removal. Docker keeps images still used elsewhere."
fi

if [[ "$REMOVE_ENV" -eq 1 ]]; then
  rm -f .env .demo-install-state
  echo "Removed generated .env/install state."
else
  rm -f .demo-install-state
fi

echo "Local uninstall complete."
echo "No shell profile, host Node/npm, host AnyDoc, launch service, Docker daemon setting, or Obsidian desktop setting was modified."
