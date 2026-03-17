#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
DATE="${1:-$(date +%Y-%m-%d)}"
TODAY=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)
LOG_FILE="$LOG_DIR/$DATE.log"
CLAUDE="${HOME}/.local/bin/claude"

# Ensure we can run even if Claude Code is open
unset CLAUDECODE

mkdir -p "$LOG_DIR"

echo "[$DATE $TIME] Starting AI News Briefing..." >> "$LOG_FILE"

# Read prompt
PROMPT="$(cat "$SCRIPT_DIR/prompt.md")"

# Inject date override if running for a non-today date
if [[ "$DATE" != "$TODAY" ]]; then
  DATE_PREFIX="BRIEFING DATE OVERRIDE: $DATE
Generate the briefing for $DATE, NOT today ($TODAY).
Search for AI news from $DATE (past 24 hours relative to that date).
The Notion page title should use $DATE.
The card.json filename should use $DATE (logs/$DATE-card.json).
---

"
  PROMPT="${DATE_PREFIX}${PROMPT}"
  echo "[$DATE $(date +%H:%M:%S)] Date override: generating briefing for $DATE" >> "$LOG_FILE"
fi

# Run Claude in print mode with the news prompt
# --model sonnet: cost-efficient for search+compilation
# --dangerously-skip-permissions: required for headless/automated execution
# --max-budget-usd: safety cap per run
"$CLAUDE" -p \
  --model sonnet \
  --dangerously-skip-permissions \
  --max-budget-usd 2.00 \
  "$PROMPT" \
  >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
TIME=$(date +%H:%M:%S)

if [ $EXIT_CODE -eq 0 ]; then
  echo "[$DATE $TIME] Briefing complete. Check Notion for today's report." >> "$LOG_FILE"

  # Post summary to Teams channel if webhook is configured
  TEAMS_SCRIPT="$SCRIPT_DIR/scripts/notify-teams.sh"
  CARD_FILE="$LOG_DIR/$DATE-card.json"
  if [[ -x "$TEAMS_SCRIPT" && -n "${AI_BRIEFING_TEAMS_WEBHOOK:-}" ]]; then
    echo "[$DATE $(date +%H:%M:%S)] Sending Teams notification..." >> "$LOG_FILE"
    if "$TEAMS_SCRIPT" --card-file "$CARD_FILE"; then
      echo "[$DATE $(date +%H:%M:%S)] Teams notification sent." >> "$LOG_FILE"
    else
      echo "[$DATE $(date +%H:%M:%S)] Teams notification failed." >> "$LOG_FILE"
    fi
  fi
else
  echo "[$DATE $TIME] Briefing FAILED with exit code $EXIT_CODE." >> "$LOG_FILE"
fi

# Clean up logs older than 30 days
find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
