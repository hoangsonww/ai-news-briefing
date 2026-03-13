#!/bin/bash
set -euo pipefail

# notify-teams.sh — Post today's AI briefing TL;DR to a Teams channel via webhook.
# Usage:
#   ./scripts/notify-teams.sh                              # Auto-detect from today's log
#   ./scripts/notify-teams.sh --webhook-url "https://..."  # Override webhook URL
#   ./scripts/notify-teams.sh --log-file "path/to.log"     # Use specific log file

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATE=$(date +%Y-%m-%d)

WEBHOOK_URL="${AI_BRIEFING_TEAMS_WEBHOOK:-}"
LOG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webhook-url) WEBHOOK_URL="$2"; shift 2 ;;
    --log-file)    LOG_FILE="$2";    shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="$SCRIPT_DIR/logs/$DATE.log"
fi

if [[ -z "$WEBHOOK_URL" ]]; then
  echo "Error: No webhook URL. Set AI_BRIEFING_TEAMS_WEBHOOK env var or pass --webhook-url." >&2
  exit 1
fi

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Error: Log file not found: $LOG_FILE" >&2
  exit 1
fi

if ! grep -q "Briefing complete" "$LOG_FILE"; then
  echo "Briefing did not complete successfully. Skipping Teams notification."
  exit 0
fi

# Build the Adaptive Card JSON payload
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

python3 "$SCRIPT_DIR/scripts/build-teams-card.py" "$LOG_FILE" > "$TMPFILE"

# POST to webhook using file input (avoids shell encoding issues)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json; charset=utf-8" \
  -d @"$TMPFILE" \
  "$WEBHOOK_URL")

if [[ "$HTTP_CODE" =~ ^2 ]]; then
  echo "Teams notification sent successfully."
else
  echo "Teams notification failed (HTTP $HTTP_CODE)." >&2
  exit 1
fi
