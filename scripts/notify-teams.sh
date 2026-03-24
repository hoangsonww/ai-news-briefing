#!/bin/bash
set -euo pipefail

# notify-teams.sh — POST a pre-built Adaptive Card JSON to a Teams webhook.
# The AI generates the card JSON directly. This script just sends it.
#
# Usage:
#   ./scripts/notify-teams.sh                            # Post to first URL in env var
#   ./scripts/notify-teams.sh --webhook-url "https://..."
#   ./scripts/notify-teams.sh --all                      # Post to ALL semicolon-separated URLs
#   ./scripts/notify-teams.sh --card-file "path/to/card.json"
#
# Multiple webhooks: set AI_BRIEFING_TEAMS_WEBHOOK to semicolon-separated URLs.
# By default only the first URL is used. Pass --all to post to every URL.

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATE=$(date +%Y-%m-%d)

WEBHOOK_URL="${AI_BRIEFING_TEAMS_WEBHOOK:-}"
CARD_FILE=""
POST_ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webhook-url) WEBHOOK_URL="$2"; shift 2 ;;
    --card-file)   CARD_FILE="$2";   shift 2 ;;
    --all)         POST_ALL=true;    shift ;;
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

# Split on semicolons into array
IFS=';' read -ra ALL_URLS <<< "$WEBHOOK_URL"

# Trim whitespace and drop empties
CLEAN_URLS=()
for u in "${ALL_URLS[@]}"; do
  trimmed="$(echo "$u" | xargs)"
  [[ -n "$trimmed" ]] && CLEAN_URLS+=("$trimmed")
done

if [[ ${#CLEAN_URLS[@]} -eq 0 ]]; then
  echo "Error: No valid webhook URLs found." >&2
  exit 1
fi

# Default: first URL only. --all: every URL.
if [[ "$POST_ALL" == "true" ]]; then
  URLS=("${CLEAN_URLS[@]}")
else
  URLS=("${CLEAN_URLS[0]}")
  if [[ ${#CLEAN_URLS[@]} -gt 1 ]]; then
    echo "Using first webhook URL (pass --all to post to all ${#CLEAN_URLS[@]} URLs)."
  fi
fi

TOTAL=${#URLS[@]}
FAILED=0

for url in "${URLS[@]}"; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 30 \
    -X POST \
    -H "Content-Type: application/json; charset=utf-8" \
    -d @"$CARD_FILE" \
    "$url" 2>/dev/null) || HTTP_CODE="000"

  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    echo "Teams notification sent (HTTP $HTTP_CODE)."
  else
    echo "Warning: Teams notification failed for $url (HTTP $HTTP_CODE)." >&2
    FAILED=$((FAILED + 1))
  fi
done

if [[ "$FAILED" -eq "$TOTAL" ]]; then
  echo "Error: All $FAILED webhook(s) failed." >&2
  exit 1
fi

if [[ "$FAILED" -gt 0 ]]; then
  echo "$FAILED of $TOTAL webhook(s) failed. Check warnings above."
fi
