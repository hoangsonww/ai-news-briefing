#!/bin/bash
set -euo pipefail

# cost-report.sh — Estimate API costs from log files.
# Parses log output for token usage and cost indicators.
# Usage:
#   ./scripts/cost-report.sh              # Current month
#   ./scripts/cost-report.sh --month 03   # Specific month
#   ./scripts/cost-report.sh --all        # All time

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
MONTH=""
ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --month) MONTH="$2"; shift 2 ;;
        --all) ALL=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ ! -d "$LOG_DIR" ]; then
    echo "No logs directory found."
    exit 0
fi

YEAR=$(date +%Y)
if [ -z "$MONTH" ] && [ "$ALL" = false ]; then
    MONTH=$(date +%m)
fi

echo ""
echo "  AI News Briefing — Cost Report"
echo "  ==============================="
echo ""

TOTAL_RUNS=0
SUCCESS_RUNS=0
FAILED_RUNS=0
TOTAL_SIZE=0

for log in "$LOG_DIR"/*.log; do
    [ -f "$log" ] || continue
    BASENAME=$(basename "$log" .log)

    # Filter by date pattern
    [[ ! "$BASENAME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue

    # Filter by month if specified
    if [ -n "$MONTH" ]; then
        LOG_MONTH=${BASENAME:5:2}
        LOG_YEAR=${BASENAME:0:4}
        [ "$LOG_YEAR" != "$YEAR" ] && continue
        [ "$LOG_MONTH" != "$MONTH" ] && continue
    fi

    TOTAL_RUNS=$((TOTAL_RUNS + 1))
    FILE_SIZE=$(wc -c < "$log" | tr -d ' ')
    TOTAL_SIZE=$((TOTAL_SIZE + FILE_SIZE))

    if grep -q "Briefing complete" "$log" 2>/dev/null; then
        SUCCESS_RUNS=$((SUCCESS_RUNS + 1))
    elif grep -q "FAILED" "$log" 2>/dev/null; then
        FAILED_RUNS=$((FAILED_RUNS + 1))
    fi
done

if [ "$TOTAL_RUNS" -eq 0 ]; then
    PERIOD="all time"
    [ -n "$MONTH" ] && PERIOD="$YEAR-$MONTH"
    echo "  No runs found for $PERIOD."
    echo ""
    exit 0
fi

# Cost estimates (based on Sonnet model defaults)
# Typical: $0.70-$1.40 per run, average ~$1.05
AVG_COST="1.05"
EST_TOTAL=$(echo "$SUCCESS_RUNS * $AVG_COST" | bc 2>/dev/null || echo "N/A")
EST_LOW=$(echo "$SUCCESS_RUNS * 0.70" | bc 2>/dev/null || echo "N/A")
EST_HIGH=$(echo "$SUCCESS_RUNS * 1.40" | bc 2>/dev/null || echo "N/A")

PERIOD_LABEL="all time"
[ -n "$MONTH" ] && PERIOD_LABEL="$YEAR-$MONTH"

SIZE_MB=$(echo "scale=1; $TOTAL_SIZE / 1048576" | bc 2>/dev/null || echo "N/A")

printf "  %-28s %s\n" "Period:" "$PERIOD_LABEL"
printf "  %-28s %s\n" "Total runs:" "$TOTAL_RUNS"
printf "  %-28s %s\n" "Successful:" "$SUCCESS_RUNS"
printf "  %-28s %s\n" "Failed:" "$FAILED_RUNS"
printf "  %-28s %s\n" "Total log size:" "${SIZE_MB} MB"
echo ""
echo "  Cost Estimates (Sonnet model)"
echo "  -----------------------------"
printf "  %-28s %s\n" "Low estimate (\$0.70/run):" "\$$EST_LOW"
printf "  %-28s %s\n" "Average (\$1.05/run):" "\$$EST_TOTAL"
printf "  %-28s %s\n" "High estimate (\$1.40/run):" "\$$EST_HIGH"
printf "  %-28s %s\n" "Budget cap (\$2.00/run):" "\$$(echo "$TOTAL_RUNS * 2.00" | bc 2>/dev/null || echo "N/A") max"
echo ""

if [ "$FAILED_RUNS" -gt 0 ]; then
    FAIL_RATE=$(echo "scale=0; $FAILED_RUNS * 100 / $TOTAL_RUNS" | bc 2>/dev/null || echo "N/A")
    echo "  Note: ${FAIL_RATE}% failure rate. Failed runs still consume some API budget."
    echo ""
fi
