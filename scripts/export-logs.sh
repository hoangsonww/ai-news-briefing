#!/bin/bash
set -euo pipefail

# export-logs.sh — Archive logs into a compressed tarball.
# Exports all logs (or a date range) to a .tar.gz archive.
# Usage:
#   ./scripts/export-logs.sh                    # All logs
#   ./scripts/export-logs.sh --from 2026-03-01  # From date
#   ./scripts/export-logs.sh --from 2026-03-01 --to 2026-03-07  # Range
#   ./scripts/export-logs.sh --output ~/backup  # Custom output dir

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
OUTPUT_DIR="$SCRIPT_DIR"
FROM=""
TO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --from) FROM="$2"; shift 2 ;;
        --to) TO="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; echo "Usage: export-logs.sh [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--output DIR]"; exit 1 ;;
    esac
done

if [ ! -d "$LOG_DIR" ]; then
    echo "No logs directory found at $LOG_DIR"
    exit 1
fi

# Collect matching files
TMPLIST=$(mktemp)
trap 'rm -f "$TMPLIST"' EXIT

for log in "$LOG_DIR"/*.log; do
    [ -f "$log" ] || continue
    BASENAME=$(basename "$log" .log)

    # Skip non-date logs unless no range specified
    if [[ ! "$BASENAME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        if [ -z "$FROM" ] && [ -z "$TO" ]; then
            echo "$log" >> "$TMPLIST"
        fi
        continue
    fi

    # Apply date filters
    if [ -n "$FROM" ] && [[ "$BASENAME" < "$FROM" ]]; then continue; fi
    if [ -n "$TO" ] && [[ "$BASENAME" > "$TO" ]]; then continue; fi

    echo "$log" >> "$TMPLIST"
done

COUNT=$(wc -l < "$TMPLIST" | tr -d ' ')
if [ "$COUNT" -eq 0 ]; then
    echo "No logs matched the specified criteria."
    exit 0
fi

# Build archive name
DATE=$(date +%Y-%m-%d)
RANGE_LABEL=""
if [ -n "$FROM" ]; then RANGE_LABEL="_from-${FROM}"; fi
if [ -n "$TO" ]; then RANGE_LABEL="${RANGE_LABEL}_to-${TO}"; fi
ARCHIVE="$OUTPUT_DIR/ai-briefing-logs_${DATE}${RANGE_LABEL}.tar.gz"

mkdir -p "$OUTPUT_DIR"

# Create archive
tar -czf "$ARCHIVE" -T "$TMPLIST" --transform='s|.*/||' 2>/dev/null || \
    tar -czf "$ARCHIVE" $(cat "$TMPLIST") 2>/dev/null

SIZE=$(du -h "$ARCHIVE" | cut -f1 | tr -d ' ')
echo ""
echo "  Exported $COUNT log file(s) to:"
echo "  $ARCHIVE ($SIZE)"
echo ""
