#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)
LOG_FILE="$LOG_DIR/$DATE.log"
CLAUDE="${HOME}/.local/bin/claude"

# Ensure we can run even if Claude Code is open
unset CLAUDECODE

mkdir -p "$LOG_DIR"

echo "[$DATE $TIME] Starting AI News Briefing..." >> "$LOG_FILE"

# Run Claude in print mode with the news prompt
# --model sonnet: cost-efficient for search+compilation
# --dangerously-skip-permissions: required for headless/automated execution
# --max-budget-usd: safety cap per run
"$CLAUDE" -p \
  --model sonnet \
  --dangerously-skip-permissions \
  --max-budget-usd 2.00 \
  "$(cat "$SCRIPT_DIR/prompt.md")" \
  >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
TIME=$(date +%H:%M:%S)

if [ $EXIT_CODE -eq 0 ]; then
  echo "[$DATE $TIME] Briefing complete. Check Notion for today's report." >> "$LOG_FILE"

  # Post summary to Teams channel if webhook is configured
  TEAMS_SCRIPT="$SCRIPT_DIR/scripts/notify-teams.sh"
  if [[ -x "$TEAMS_SCRIPT" && -n "${AI_BRIEFING_TEAMS_WEBHOOK:-}" ]]; then
    echo "[$DATE $(date +%H:%M:%S)] Sending Teams notification..." >> "$LOG_FILE"
    if "$TEAMS_SCRIPT" --log-file "$LOG_FILE"; then
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
