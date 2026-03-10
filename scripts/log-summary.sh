#!/bin/bash
set -euo pipefail

# log-summary.sh — Summarize recent briefing runs.
# Shows date, status (pass/fail), file size, and duration for each log.
# Usage: ./scripts/log-summary.sh [N]  (default: last 14 days)

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LIMIT=${1:-14}

green()  { printf "\033[32m%s\033[0m" "$1"; }
red()    { printf "\033[31m%s\033[0m" "$1"; }
dim()    { printf "\033[90m%s\033[0m" "$1"; }

echo ""
echo "  AI News Briefing — Run Summary (last $LIMIT days)"
echo "  =================================================="
echo ""

if [ ! -d "$LOG_DIR" ]; then
    echo "  No logs directory found."
    exit 0
fi

printf "  %-14s %-10s %-10s %s\n" "Date" "Status" "Size" "Details"
printf "  %-14s %-10s %-10s %s\n" "----------" "------" "------" "-------"

SUCCESS=0
FAILED=0
TOTAL=0

# List log files sorted by name (date), take last N
for log in $(ls -1 "$LOG_DIR"/*.log 2>/dev/null | grep -E '/[0-9]{4}-[0-9]{2}-[0-9]{2}\.log$' | sort -r | head -n "$LIMIT"); do
    DATE=$(basename "$log" .log)
    SIZE=$(du -h "$log" 2>/dev/null | cut -f1 | tr -d ' ')
    TOTAL=$((TOTAL + 1))

    if grep -q "Briefing complete" "$log" 2>/dev/null; then
        STATUS="$(green "PASS")"
        SUCCESS=$((SUCCESS + 1))
        DETAIL=$(grep -o "Check Notion.*" "$log" 2>/dev/null | tail -1 || echo "")
    elif grep -q "FAILED" "$log" 2>/dev/null; then
        STATUS="$(red "FAIL")"
        FAILED=$((FAILED + 1))
        DETAIL=$(grep "FAILED" "$log" 2>/dev/null | tail -1 | sed 's/.*FAILED/FAILED/' || echo "")
    else
        STATUS="$(dim "????")"
        DETAIL="No completion marker found"
    fi

    printf "  %-14s %-10s %-10s %s\n" "$DATE" "$STATUS" "$SIZE" "$DETAIL"
done

if [ "$TOTAL" -eq 0 ]; then
    echo "  No dated log files found."
else
    echo ""
    echo "  --------------------------------"
    printf "  %d runs: " "$TOTAL"
    printf "%s succeeded" "$(green "$SUCCESS")"
    if [ "$FAILED" -gt 0 ]; then printf ", %s failed" "$(red "$FAILED")"; fi
    INCOMPLETE=$((TOTAL - SUCCESS - FAILED))
    if [ "$INCOMPLETE" -gt 0 ]; then printf ", %s unknown" "$(dim "$INCOMPLETE")"; fi
    echo ""
fi
echo ""
