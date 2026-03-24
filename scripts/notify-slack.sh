#!/bin/bash
set -euo pipefail

# notify-slack.sh — Convert a Teams Adaptive Card JSON to Slack Block Kit and POST it.
#
# Usage:
#   ./scripts/notify-slack.sh                            # Post to first URL in env var
#   ./scripts/notify-slack.sh --webhook-url "https://..."
#   ./scripts/notify-slack.sh --all                      # Post to ALL semicolon-separated URLs
#   ./scripts/notify-slack.sh --card-file "path/to/card.json"
#
# Multiple webhooks: set AI_BRIEFING_SLACK_WEBHOOK to semicolon-separated URLs.
# By default only the first URL is used. Pass --all to post to every URL.

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATE=$(date +%Y-%m-%d)

WEBHOOK_URL="${AI_BRIEFING_SLACK_WEBHOOK:-}"
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
  echo "Error: No webhook URL. Set AI_BRIEFING_SLACK_WEBHOOK or pass --webhook-url." >&2
  exit 1
fi

if [[ ! -f "$CARD_FILE" ]]; then
  echo "Error: Card file not found: $CARD_FILE" >&2
  exit 1
fi

# Convert Teams card JSON to Slack Block Kit JSON
CONVERTER="$SCRIPT_DIR/scripts/teams-to-slack.py"
if [[ ! -f "$CONVERTER" ]]; then
  echo "Error: Converter script not found: $CONVERTER" >&2
  exit 1
fi

SLACK_PAYLOAD=$(python3 "$CONVERTER" "$CARD_FILE") || {
  echo "Error: Failed to convert card to Slack format." >&2
  exit 1
}

# Validate the converted payload is valid JSON
if ! echo "$SLACK_PAYLOAD" | python3 -m json.tool > /dev/null 2>&1; then
  echo "Error: Converted Slack payload is not valid JSON." >&2
  exit 1
fi

# Write to temp file for curl (avoids shell escaping issues with large JSON)
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
echo "$SLACK_PAYLOAD" > "$TMPFILE"

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
    echo "Using first Slack webhook URL (pass --all to post to all ${#CLEAN_URLS[@]} URLs)."
  fi
fi

TOTAL=${#URLS[@]}
FAILED=0

for url in "${URLS[@]}"; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 30 \
    -X POST \
    -H "Content-Type: application/json; charset=utf-8" \
    -d @"$TMPFILE" \
    "$url" 2>/dev/null) || HTTP_CODE="000"

  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    echo "Slack notification sent (HTTP $HTTP_CODE)."
  else
    echo "Warning: Slack notification failed for $url (HTTP $HTTP_CODE)." >&2
    FAILED=$((FAILED + 1))
  fi
done

if [[ "$FAILED" -eq "$TOTAL" ]]; then
  echo "Error: All $FAILED Slack webhook(s) failed." >&2
  exit 1
fi

if [[ "$FAILED" -gt 0 ]]; then
  echo "$FAILED of $TOTAL Slack webhook(s) failed. Check warnings above."
fi
