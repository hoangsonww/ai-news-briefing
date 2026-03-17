#!/bin/bash
set -euo pipefail

# notify-teams.sh — POST a pre-built Adaptive Card JSON to Teams webhook.
# The AI generates the card JSON directly. This script just sends it.
#
# Usage:
#   ./scripts/notify-teams.sh
#   ./scripts/notify-teams.sh --webhook-url "https://..."
#   ./scripts/notify-teams.sh --card-file "path/to/card.json"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATE=$(date +%Y-%m-%d)

WEBHOOK_URL="${AI_BRIEFING_TEAMS_WEBHOOK:-}"
CARD_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webhook-url) WEBHOOK_URL="$2"; shift 2 ;;
    --card-file)   CARD_FILE="$2";   shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CARD_FILE" ]]; then
  CARD_FILE="$SCRIPT_DIR/logs/$DATE-card.json"
fi

if [[ -z "$WEBHOOK_URL" ]]; then
  echo "Error: No webhook URL. Set AI_BRIEFING_TEAMS_WEBHOOK or pass --webhook-url." >&2
  exit 1
fi

if [[ ! -f "$CARD_FILE" ]]; then
  echo "Error: Card file not found: $CARD_FILE" >&2
  exit 1
fi

# Validate it's actual JSON before sending
if ! python3 -m json.tool "$CARD_FILE" > /dev/null 2>&1; then
  echo "Error: $CARD_FILE is not valid JSON." >&2
  exit 1
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json; charset=utf-8" \
  -d @"$CARD_FILE" \
  "$WEBHOOK_URL")

if [[ "$HTTP_CODE" =~ ^2 ]]; then
  echo "Teams notification sent successfully."
else
  echo "Teams notification failed (HTTP $HTTP_CODE)." >&2
  exit 1
fi
