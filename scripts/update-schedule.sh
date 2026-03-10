#!/bin/bash
set -euo pipefail

# update-schedule.sh — Change the daily briefing schedule time (macOS only).
# Updates the plist and reloads the launchd agent.
# Usage: ./scripts/update-schedule.sh HH MM
# Example: ./scripts/update-schedule.sh 07 30   # Set to 7:30 AM

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_SRC="$SCRIPT_DIR/com.ainews.briefing.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.ainews.briefing.plist"
LABEL="com.ainews.briefing"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script is for macOS only."
    echo "On Windows, use: .\\install-task.ps1 -Hour HH -Minute MM"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: update-schedule.sh HOUR MINUTE"
    echo "Example: update-schedule.sh 7 30  (sets schedule to 7:30 AM)"
    exit 1
fi

HOUR="$1"
MINUTE="$2"

# Validate
if ! [[ "$HOUR" =~ ^[0-9]+$ ]] || [ "$HOUR" -lt 0 ] || [ "$HOUR" -gt 23 ]; then
    echo "Invalid hour: $HOUR (must be 0-23)"
    exit 1
fi
if ! [[ "$MINUTE" =~ ^[0-9]+$ ]] || [ "$MINUTE" -lt 0 ] || [ "$MINUTE" -gt 59 ]; then
    echo "Invalid minute: $MINUTE (must be 0-59)"
    exit 1
fi

echo ""
echo "  Updating schedule to $(printf '%02d:%02d' "$HOUR" "$MINUTE")..."

# Update the plist source file
# Replace the Hour and Minute values in StartCalendarInterval
sed -i.bak -E "
    /StartCalendarInterval/,/<\/dict>/ {
        /<key>Hour<\/key>/{
            n; s/<integer>[0-9]+<\/integer>/<integer>$HOUR<\/integer>/
        }
        /<key>Minute<\/key>/{
            n; s/<integer>[0-9]+<\/integer>/<integer>$MINUTE<\/integer>/
        }
    }
" "$PLIST_SRC"
rm -f "${PLIST_SRC}.bak"

# Unload existing agent (ignore errors if not loaded)
launchctl unload "$PLIST_DEST" 2>/dev/null || true

# Copy updated plist and reload
cp "$PLIST_SRC" "$PLIST_DEST"
launchctl load "$PLIST_DEST"

echo "  Plist updated and agent reloaded."
echo ""
echo "  New schedule: daily at $(printf '%02d:%02d' "$HOUR" "$MINUTE")"
echo "  Verify: launchctl list | grep ainews"
echo ""
