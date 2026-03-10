#!/bin/bash
set -euo pipefail

# notify.sh — Send a native OS notification after briefing completes.
# Reads today's log to determine success/failure and sends appropriate notification.
# Can be called from briefing.sh or independently.
# Usage: ./scripts/notify.sh [success|failure|custom "message"]

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/$DATE.log"

TITLE="AI News Briefing"
STATUS="${1:-auto}"
CUSTOM_MSG="${2:-}"

# Auto-detect status from log
if [ "$STATUS" = "auto" ]; then
    if [ ! -f "$LOG_FILE" ]; then
        STATUS="failure"
        CUSTOM_MSG="No log file found for today."
    elif grep -q "Briefing complete" "$LOG_FILE" 2>/dev/null; then
        STATUS="success"
    elif grep -q "FAILED" "$LOG_FILE" 2>/dev/null; then
        STATUS="failure"
        CUSTOM_MSG=$(grep "FAILED" "$LOG_FILE" 2>/dev/null | tail -1 || echo "Check log for details.")
    else
        STATUS="failure"
        CUSTOM_MSG="Run may still be in progress or ended without status."
    fi
fi

case "$STATUS" in
    success)
        MSG="${CUSTOM_MSG:-Briefing complete. Check Notion for today's report.}"
        SOUND="default"
        ;;
    failure)
        MSG="${CUSTOM_MSG:-Briefing failed. Check logs for details.}"
        SOUND="Basso"
        ;;
    custom)
        MSG="${CUSTOM_MSG:-No message provided.}"
        SOUND="default"
        ;;
    *)
        echo "Usage: notify.sh [success|failure|custom \"message\"]"
        exit 1
        ;;
esac

# Detect platform and send notification
UNAME=$(uname -s)

if [ "$UNAME" = "Darwin" ]; then
    # macOS: osascript notification
    osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"$SOUND\""
    echo "Notification sent (macOS): $MSG"

elif command -v notify-send >/dev/null 2>&1; then
    # Linux with libnotify
    ICON="dialog-information"
    [ "$STATUS" = "failure" ] && ICON="dialog-error"
    notify-send "$TITLE" "$MSG" --icon="$ICON"
    echo "Notification sent (Linux): $MSG"

elif command -v powershell.exe >/dev/null 2>&1; then
    # Windows via Git Bash / WSL
    powershell.exe -NoProfile -Command "
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
        \$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
        \$xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\"><text>$TITLE</text><text>$MSG</text></binding></visual></toast>')
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('AI News Briefing').Show([Windows.UI.Notifications.ToastNotification]::new(\$xml))
    " 2>/dev/null || echo "Toast notification failed. Message: $MSG"

else
    # Fallback: just print
    echo "[$TITLE] $MSG"
    echo "(No notification system detected — printed to terminal)"
fi
