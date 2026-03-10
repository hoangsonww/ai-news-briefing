#!/bin/bash
set -euo pipefail

# log-search.sh — Search across all logs for a keyword or pattern.
# Useful for finding when a specific topic, company, or error appeared.
# Usage:
#   ./scripts/log-search.sh "Anthropic"          # Search for keyword
#   ./scripts/log-search.sh "FAILED" --count     # Count matches per log
#   ./scripts/log-search.sh "OpenAI" --context 3 # Show surrounding lines

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
PATTERN="${1:-}"
MODE="content"
CONTEXT=1

if [ -z "$PATTERN" ]; then
    echo "Usage: log-search.sh PATTERN [--count|--context N]"
    exit 1
fi

shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --count) MODE="count"; shift ;;
        --context) CONTEXT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [ ! -d "$LOG_DIR" ]; then
    echo "No logs directory found."
    exit 0
fi

echo ""
echo "  Searching logs for: \"$PATTERN\""
echo "  ================================"
echo ""

case "$MODE" in
    count)
        TOTAL=0
        for log in $(ls -1t "$LOG_DIR"/*.log 2>/dev/null); do
            COUNT=$(grep -ci "$PATTERN" "$log" 2>/dev/null || echo "0")
            if [ "$COUNT" -gt 0 ]; then
                printf "  %-24s %s matches\n" "$(basename "$log")" "$COUNT"
                TOTAL=$((TOTAL + COUNT))
            fi
        done
        echo ""
        echo "  Total: $TOTAL matches across all logs"
        ;;

    content)
        grep -rn --color=auto -C "$CONTEXT" -i "$PATTERN" "$LOG_DIR"/*.log 2>/dev/null | \
            sed "s|$LOG_DIR/||g" || echo "  No matches found."
        ;;
esac

echo ""
