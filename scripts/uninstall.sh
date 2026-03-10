#!/bin/bash
set -euo pipefail

# uninstall.sh — Fully remove AI News Briefing scheduler and optional cleanup.
# Usage:
#   ./scripts/uninstall.sh              # Remove scheduler only
#   ./scripts/uninstall.sh --all        # Remove scheduler + logs + backups

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REMOVE_ALL=false

[ "${1:-}" = "--all" ] && REMOVE_ALL=true

echo ""
echo "  AI News Briefing — Uninstall"
echo "  ============================="
echo ""

UNAME=$(uname -s)

# --- Remove Scheduler ---
if [ "$UNAME" = "Darwin" ]; then
    PLIST="$HOME/Library/LaunchAgents/com.ainews.briefing.plist"
    if launchctl list 2>/dev/null | grep -q "ainews"; then
        launchctl unload "$PLIST" 2>/dev/null || true
        echo "  [OK] launchd agent unloaded"
    else
        echo "  [--] launchd agent was not loaded"
    fi

    if [ -f "$PLIST" ]; then
        rm -f "$PLIST"
        echo "  [OK] Plist removed from ~/Library/LaunchAgents/"
    fi

    # Remove ai-news CLI shortcut
    AI_NEWS="$HOME/.local/bin/ai-news"
    if [ -f "$AI_NEWS" ]; then
        rm -f "$AI_NEWS"
        echo "  [OK] ai-news CLI shortcut removed"
    fi
else
    echo "  (Not macOS — skipping launchd removal)"
fi

# Windows via Git Bash
if command -v schtasks.exe >/dev/null 2>&1; then
    if schtasks.exe //query //tn AiNewsBriefing >/dev/null 2>&1; then
        schtasks.exe //delete //tn AiNewsBriefing //f >/dev/null 2>&1
        echo "  [OK] Windows scheduled task removed"
    else
        echo "  [--] Windows scheduled task was not found"
    fi
fi

# --- Remove Logs & Backups ---
if [ "$REMOVE_ALL" = true ]; then
    echo ""
    echo "  Cleaning up files..."

    if [ -d "$SCRIPT_DIR/logs" ]; then
        rm -rf "$SCRIPT_DIR/logs"
        echo "  [OK] logs/ directory removed"
    fi

    if [ -d "$SCRIPT_DIR/backups" ]; then
        rm -rf "$SCRIPT_DIR/backups"
        echo "  [OK] backups/ directory removed"
    fi
fi

echo ""
echo "  Uninstall complete."
echo "  The project files remain in: $SCRIPT_DIR"
echo "  To fully remove, delete the directory manually."
echo ""
