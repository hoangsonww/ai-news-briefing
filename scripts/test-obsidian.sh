#!/bin/bash
set -euo pipefail

# test-obsidian.sh — Test Obsidian vault connectivity.
# Verifies that the vault directory exists and is writable.
# Usage: ./scripts/test-obsidian.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo "  AI News Briefing — Obsidian Vault Connectivity Test"
echo "  ===================================================="
echo ""

VAULT="${AI_BRIEFING_OBSIDIAN_VAULT:-}"

if [[ -z "$VAULT" ]]; then
  echo "  FAIL  AI_BRIEFING_OBSIDIAN_VAULT is not set."
  echo ""
  echo "  Set it to your Obsidian vault path:"
  echo "    export AI_BRIEFING_OBSIDIAN_VAULT=\"/path/to/your/vault\""
  echo ""
  exit 1
fi

echo "  Vault path: $VAULT"

if [[ ! -d "$VAULT" ]]; then
  echo "  FAIL  Directory does not exist: $VAULT"
  exit 1
fi
echo "  Directory:  exists"

if [[ ! -w "$VAULT" ]]; then
  echo "  FAIL  Directory is not writable: $VAULT"
  exit 1
fi
echo "  Writable:   yes"

# Check if it looks like an Obsidian vault
if [[ -d "$VAULT/.obsidian" ]]; then
  echo "  Obsidian:   .obsidian config found (confirmed vault)"
else
  echo "  Obsidian:   no .obsidian config (directory will work but may not be initialized as a vault)"
fi

# Check subdirectories
BRIEFINGS_DIR="$VAULT/AI-News-Briefings"
TOPICS_DIR="$VAULT/Topics"

if [[ -d "$BRIEFINGS_DIR" ]]; then
  COUNT=$(find "$BRIEFINGS_DIR" -name "*.md" -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  echo "  Briefings:  $COUNT file(s) in AI-News-Briefings/"
else
  echo "  Briefings:  AI-News-Briefings/ will be created on first publish"
fi

if [[ -d "$TOPICS_DIR" ]]; then
  COUNT=$(find "$TOPICS_DIR" -name "*.md" -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  echo "  Topics:     $COUNT topic page(s) in Topics/"
else
  echo "  Topics:     Topics/ will be created on first publish"
fi

echo ""
echo "  Test complete. Obsidian vault is ready."
echo ""
