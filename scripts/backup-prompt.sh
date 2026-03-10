#!/bin/bash
set -euo pipefail

# backup-prompt.sh — Version and backup prompt.md before making changes.
# Creates timestamped copies in a backups/ directory.
# Usage:
#   ./scripts/backup-prompt.sh              # Backup current prompt
#   ./scripts/backup-prompt.sh --list       # List all backups
#   ./scripts/backup-prompt.sh --restore N  # Restore backup N (by index)
#   ./scripts/backup-prompt.sh --diff N     # Diff backup N against current

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT="$SCRIPT_DIR/prompt.md"
BACKUP_DIR="$SCRIPT_DIR/backups"
ACTION="${1:-backup}"
ARG="${2:-}"

mkdir -p "$BACKUP_DIR"

list_backups() {
    echo ""
    echo "  Prompt Backups"
    echo "  =============="
    echo ""
    local i=1
    for f in $(ls -1t "$BACKUP_DIR"/prompt-*.md 2>/dev/null); do
        local name=$(basename "$f")
        local size=$(du -h "$f" | cut -f1 | tr -d ' ')
        printf "  %2d. %-40s %s\n" "$i" "$name" "$size"
        i=$((i + 1))
    done
    if [ "$i" -eq 1 ]; then
        echo "  No backups found."
    fi
    echo ""
}

get_backup_by_index() {
    local idx="$1"
    local files=($(ls -1t "$BACKUP_DIR"/prompt-*.md 2>/dev/null))
    local count=${#files[@]}
    if [ "$count" -eq 0 ]; then
        echo ""
        return
    fi
    local i=$((idx - 1))
    if [ "$i" -lt 0 ] || [ "$i" -ge "$count" ]; then
        echo ""
        return
    fi
    echo "${files[$i]}"
}

case "$ACTION" in
    backup|--backup|-b)
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        DEST="$BACKUP_DIR/prompt-$TIMESTAMP.md"
        cp "$PROMPT" "$DEST"
        echo ""
        echo "  Backed up prompt.md to:"
        echo "  $DEST"
        echo ""

        # Keep only last 20 backups
        BACKUPS=($(ls -1t "$BACKUP_DIR"/prompt-*.md 2>/dev/null))
        if [ "${#BACKUPS[@]}" -gt 20 ]; then
            for old in "${BACKUPS[@]:20}"; do
                rm -f "$old"
            done
            echo "  (Pruned old backups, keeping latest 20)"
            echo ""
        fi
        ;;

    --list|-l)
        list_backups
        ;;

    --restore|-r)
        if [ -z "$ARG" ]; then
            echo "Usage: backup-prompt.sh --restore N"
            echo "Run with --list to see available backups."
            exit 1
        fi
        FILE=$(get_backup_by_index "$ARG")
        if [ -z "$FILE" ]; then
            echo "Backup #$ARG not found. Run --list to see available backups."
            exit 1
        fi
        # Backup current before restoring
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        cp "$PROMPT" "$BACKUP_DIR/prompt-$TIMESTAMP-pre-restore.md"
        cp "$FILE" "$PROMPT"
        echo ""
        echo "  Restored prompt.md from: $(basename "$FILE")"
        echo "  (Previous version backed up as: prompt-$TIMESTAMP-pre-restore.md)"
        echo ""
        ;;

    --diff|-d)
        if [ -z "$ARG" ]; then
            echo "Usage: backup-prompt.sh --diff N"
            exit 1
        fi
        FILE=$(get_backup_by_index "$ARG")
        if [ -z "$FILE" ]; then
            echo "Backup #$ARG not found."
            exit 1
        fi
        echo ""
        echo "  Diff: $(basename "$FILE") vs current prompt.md"
        echo "  ================================================"
        echo ""
        diff --color=auto -u "$FILE" "$PROMPT" || true
        echo ""
        ;;

    *)
        echo "Usage: backup-prompt.sh [--backup|--list|--restore N|--diff N]"
        exit 1
        ;;
esac
