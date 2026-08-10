#!/bin/bash
#
# deploy.sh — Build + deploy one or all ParaguAI client sites to Cloudflare Pages.
#
# Usage:
#   ./deploy.sh all                  # deploy everything
#   ./deploy.sh magnolia-peluqueria  # deploy one
#   ./deploy.sh --dry-run all        # preview only
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENTS_DIR="$SCRIPT_DIR/clients"
DRY_RUN=false

# Parse args
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  shift
fi

target="${1:-}"

if [ -z "$target" ] || [ "$target" = "help" ] || [ "$target" = "-h" ]; then
  echo "Usage: $0 [--dry-run] <client-name|all>"
  echo ""
  echo "Available clients:"
  for d in "$CLIENTS_DIR"/*/; do
    if [ -d "$d" ]; then
      echo "  $(basename "$d")"
    fi
  done
  exit 0
fi

deploy_one() {
  local client="$1"
  local path="$CLIENTS_DIR/$client"
  if [ ! -d "$path" ]; then
    echo "✗ Client not found: $client"
    return 1
  fi
  echo "▸ Deploying $client..."
  if [ -f "$path/deploy.sh" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY-RUN] would run: $path/deploy.sh"
    else
      bash "$path/deploy.sh"
    fi
  else
    echo "  ⚠ No deploy.sh in $client — skipping"
  fi
}

if [ "$target" = "all" ]; then
  echo "Deploying all clients in $CLIENTS_DIR..."
  echo ""
  for d in "$CLIENTS_DIR"/*/; do
    [ -d "$d" ] || continue
    deploy_one "$(basename "$d")"
    echo ""
  done
else
  deploy_one "$target"
fi

echo "✓ Done"
