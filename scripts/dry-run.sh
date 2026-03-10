#!/bin/bash
set -euo pipefail

# dry-run.sh — Test the briefing pipeline without writing to Notion.
# Runs Claude with a modified prompt that skips the Notion write step.
# Useful for testing search results, prompt changes, or debugging.
# Usage: ./scripts/dry-run.sh [--model haiku|sonnet|opus] [--budget 1.00]

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE="${HOME}/.local/bin/claude"
MODEL="sonnet"
BUDGET="1.00"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/$DATE-dry-run.log"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model) MODEL="$2"; shift 2 ;;
        --budget) BUDGET="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "$LOG_DIR"

echo "[$DATE $TIME] Starting DRY RUN (model=$MODEL, budget=$BUDGET)..." | tee -a "$LOG_FILE"
echo "  This will search the web and compile a briefing but NOT write to Notion." | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Build a modified prompt that replaces Step 3 with a print instruction
PROMPT=$(cat "$SCRIPT_DIR/prompt.md")

# Replace the Notion write step with a "just print" instruction
DRY_PROMPT=$(echo "$PROMPT" | sed '/^## Step 3: Write to Notion/,/^## /{
    /^## Step 3/c\## Step 3: Output the Briefing\n\nDo NOT write to Notion. Instead, print the full compiled briefing to stdout.\nFormat it exactly as you would for Notion (Markdown with ## headings, - bullets, **bold**).\nThis is a dry run for testing purposes.
    /^## [^S]/!d
}')

# Ensure we can run even if Claude Code is open
unset CLAUDECODE 2>/dev/null || true

"$CLAUDE" -p \
    --model "$MODEL" \
    --dangerously-skip-permissions \
    --max-budget-usd "$BUDGET" \
    "$DRY_PROMPT" 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}
TIME=$(date +%H:%M:%S)

echo "" | tee -a "$LOG_FILE"
if [ "$EXIT_CODE" -eq 0 ]; then
    echo "[$DATE $TIME] Dry run complete. Output above and in: $LOG_FILE" | tee -a "$LOG_FILE"
else
    echo "[$DATE $TIME] Dry run FAILED with exit code $EXIT_CODE." | tee -a "$LOG_FILE"
fi
