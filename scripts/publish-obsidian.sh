#!/bin/bash
set -euo pipefail

# publish-obsidian.sh — Publish a briefing markdown file to an Obsidian vault.
# Creates topic stub pages for graph visualization if they don't already exist.
#
# Usage:
#   ./scripts/publish-obsidian.sh --file logs/2026-04-11-obsidian.md
#   ./scripts/publish-obsidian.sh --file logs/custom-2026-04-11-090000-obsidian.md
#
# Requires: AI_BRIEFING_OBSIDIAN_VAULT environment variable set to the vault path.

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# -- Colors (auto-disable if not a terminal) ---------------
if [[ -t 1 ]]; then
  BOLD='\033[1m' DIM='\033[2m' RESET='\033[0m'
  GREEN='\033[32m' RED='\033[31m' YELLOW='\033[33m' CYAN='\033[36m'
else
  BOLD='' DIM='' RESET='' GREEN='' RED='' YELLOW='' CYAN=''
fi

# -- Defaults ----------------------------------------------
SOURCE_FILE=""

# -- Parse arguments ---------------------------------------
print_usage() {
  cat <<'EOF'
Usage: publish-obsidian.sh [OPTIONS]

Publish a briefing markdown file to an Obsidian vault with graph-ready wikilinks.

Options:
  --file, -f FILE    Source markdown file to publish (required)
  --help, -h         Show this help

Environment:
  AI_BRIEFING_OBSIDIAN_VAULT   Path to Obsidian vault directory (required)

Examples:
  ./scripts/publish-obsidian.sh --file logs/2026-04-11-obsidian.md
  AI_BRIEFING_OBSIDIAN_VAULT=~/Documents/MyVault ./scripts/publish-obsidian.sh -f logs/custom-*-obsidian.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file|-f)
      if [[ $# -lt 2 ]]; then echo "ERROR: --file requires a value" >&2; exit 1; fi
      SOURCE_FILE="$2"
      shift 2
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

# -- Validate inputs ---------------------------------------
if [[ -z "$SOURCE_FILE" ]]; then
  echo -e "  ${RED}ERROR${RESET}  --file is required" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo -e "  ${RED}ERROR${RESET}  Source file not found: $SOURCE_FILE" >&2
  exit 1
fi

VAULT="${AI_BRIEFING_OBSIDIAN_VAULT:-}"
if [[ -z "$VAULT" ]]; then
  echo -e "  ${RED}ERROR${RESET}  AI_BRIEFING_OBSIDIAN_VAULT is not set" >&2
  exit 1
fi

if [[ ! -d "$VAULT" ]]; then
  echo -e "  ${RED}ERROR${RESET}  Vault directory not found: $VAULT" >&2
  exit 1
fi

# -- Ensure vault subdirectories exist ---------------------
BRIEFINGS_DIR="$VAULT/AI-News-Briefings"
TOPICS_DIR="$VAULT/Topics"
mkdir -p "$BRIEFINGS_DIR" "$TOPICS_DIR"

# -- Copy briefing to vault --------------------------------
FILENAME="$(basename "$SOURCE_FILE" | sed 's/-obsidian\.md$/.md/')"
DEST_FILE="$BRIEFINGS_DIR/$FILENAME"

cp "$SOURCE_FILE" "$DEST_FILE"
echo -e "  ${GREEN}Published${RESET}  $DEST_FILE"

# -- Create topic stub pages for graph nodes ---------------
# Extract [[wikilinks]] from the file and create stub pages for any missing topics
TOPICS=$(grep -oE '\[\[[^]]+\]\]' "$SOURCE_FILE" | sed 's/\[\[//g; s/\]\]//g' | sort -u)

CREATED=0
EXISTING=0
while IFS= read -r topic; do
  [[ -z "$topic" ]] && continue
  TOPIC_FILE="$TOPICS_DIR/$topic.md"
  if [[ ! -f "$TOPIC_FILE" ]]; then
    cat > "$TOPIC_FILE" <<TOPICEOF
---
type: topic
created: $(date +%Y-%m-%d)
---

# $topic

This is a topic hub for **$topic** in the AI News Briefing system.

Briefings mentioning this topic are automatically linked via Obsidian's backlinks panel and graph view.

## See Also

Check the **Backlinks** panel (or graph view) to see all briefings referencing this topic.
TOPICEOF
    CREATED=$((CREATED + 1))
  else
    EXISTING=$((EXISTING + 1))
  fi
done <<< "$TOPICS"

if [[ "$CREATED" -gt 0 ]]; then
  echo -e "  ${GREEN}Topics${RESET}    $CREATED new topic page(s) created, $EXISTING already existed"
else
  echo -e "  ${DIM}Topics${RESET}    all $EXISTING topic pages already exist"
fi

echo -e "  ${DIM}Graph${RESET}     open Obsidian and check the graph view to see topic connections"
