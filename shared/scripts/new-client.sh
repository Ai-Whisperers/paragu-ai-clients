#!/bin/bash
# new-client.sh — Scaffold a new client site from the base template
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <slug> <display-name> [category]"
  echo "  e.g. $0 farmacia-san-jose 'Farmacia San José' clinic"
  exit 1
fi

SLUG="$1"
NAME="$2"
CATEGORY="${3:-other}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CLIENT_DIR="$ROOT/clients/$SLUG"

if [ -d "$CLIENT_DIR" ]; then
  echo "✗ Client already exists: $CLIENT_DIR"
  exit 1
fi

echo "▸ Creating $SLUG..."

# Copy template
cp -r "$ROOT/shared/base-template" "$CLIENT_DIR"

# Replace placeholders
cd "$CLIENT_DIR"
sed -i "s/{{CLIENT_NAME}}/$NAME/g" index.html README.md
sed -i "s/{{CLIENT_SLUG}}/$SLUG/g" client.json
sed -i "s/\"category\": \".*\"/\"category\": \"$CATEGORY\"/" client.json

# Create empty placeholder files
touch "$CLIENT_DIR"/services.json
echo "{}" > "$CLIENT_DIR"/services.json

# Commit message
echo ""
echo "✓ Created $CLIENT_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit clients/$SLUG/index.html with real content"
echo "  2. Update client.json with WhatsApp/email/address"
echo "  3. cd clients/$SLUG && ../deploy.sh"
echo ""
