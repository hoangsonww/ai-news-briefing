#!/bin/bash
set -euo pipefail

# topic-edit.sh — List, add, or remove topics from prompt.md.
# Provides a safe interface for modifying the topic list without manual editing.
# Usage:
#   ./scripts/topic-edit.sh --list                              # Show current topics
#   ./scripts/topic-edit.sh --add "AI Hardware" "GPU releases, chip announcements, custom silicon"
#   ./scripts/topic-edit.sh --remove 9                          # Remove topic #9

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT="$SCRIPT_DIR/prompt.md"
ACTION="${1:-}"

green() { printf "\033[32m%s\033[0m" "$1"; }
dim()   { printf "\033[90m%s\033[0m" "$1"; }

list_topics() {
    echo ""
    echo "  Current Topics in prompt.md"
    echo "  ==========================="
    echo ""
    grep -E '^\d+\.\s+\*\*' "$PROMPT" | while IFS= read -r line; do
        NUM=$(echo "$line" | grep -oE '^\d+')
        NAME=$(echo "$line" | sed 's/^[0-9]*\.\s*//' | sed 's/\*\*//g' | sed 's/ —.*//')
        DESC=$(echo "$line" | sed 's/.*— //')
        printf "  %2s. %-30s %s\n" "$NUM" "$NAME" "$(dim "$DESC")"
    done
    echo ""
    TOPIC_COUNT=$(grep -cE '^\d+\.\s+\*\*' "$PROMPT")
    echo "  Total: $TOPIC_COUNT topics"
    echo "  Notion 'Topics' property should be: $TOPIC_COUNT"
    echo ""
}

case "$ACTION" in
    --list|-l)
        list_topics
        ;;

    --add|-a)
        NAME="${2:-}"
        DESC="${3:-}"
        if [ -z "$NAME" ]; then
            echo "Usage: topic-edit.sh --add \"Topic Name\" \"description of what to cover\""
            exit 1
        fi

        # Auto-backup before editing
        bash "$SCRIPT_DIR/scripts/backup-prompt.sh" --backup 2>/dev/null || true

        # Find next topic number
        CURRENT_MAX=$(grep -oE '^\d+\.' "$PROMPT" | sed 's/\.//' | sort -n | tail -1)
        NEXT=$((CURRENT_MAX + 1))

        # Find the line number of the last topic and insert after it
        LAST_TOPIC_LINE=$(grep -nE '^\d+\.\s+\*\*' "$PROMPT" | tail -1 | cut -d: -f1)

        NEW_LINE="$NEXT. **$NAME** — $DESC"
        sed -i.bak "${LAST_TOPIC_LINE}a\\
${NEW_LINE}" "$PROMPT"
        rm -f "${PROMPT}.bak"

        # Update the Topics count in Notion properties
        sed -i.bak "s/\"Topics\": $CURRENT_MAX/\"Topics\": $NEXT/" "$PROMPT"
        rm -f "${PROMPT}.bak"

        echo ""
        echo "  $(green "Added topic #$NEXT: $NAME")"
        echo "  Updated Notion 'Topics' property to $NEXT"
        echo ""
        list_topics
        ;;

    --remove|-r)
        NUM="${2:-}"
        if [ -z "$NUM" ]; then
            echo "Usage: topic-edit.sh --remove N"
            exit 1
        fi

        TOPIC_LINE=$(grep -n "^${NUM}\.\s" "$PROMPT" | head -1 | cut -d: -f1)
        if [ -z "$TOPIC_LINE" ]; then
            echo "Topic #$NUM not found."
            exit 1
        fi

        TOPIC_TEXT=$(sed -n "${TOPIC_LINE}p" "$PROMPT")

        # Auto-backup before editing
        bash "$SCRIPT_DIR/scripts/backup-prompt.sh" --backup 2>/dev/null || true

        sed -i.bak "${TOPIC_LINE}d" "$PROMPT"
        rm -f "${PROMPT}.bak"

        # Renumber remaining topics
        CURRENT_COUNT=$(grep -cE '^\d+\.\s+\*\*' "$PROMPT")

        # Update Topics count
        sed -i.bak "s/\"Topics\": [0-9]*/\"Topics\": $CURRENT_COUNT/" "$PROMPT"
        rm -f "${PROMPT}.bak"

        echo ""
        echo "  Removed: $TOPIC_TEXT"
        echo "  Updated Notion 'Topics' property to $CURRENT_COUNT"
        echo "  (Note: topic numbers may need manual renumbering)"
        echo ""
        list_topics
        ;;

    *)
        echo "Usage: topic-edit.sh [--list|--add NAME DESC|--remove N]"
        echo ""
        echo "  --list            Show current topics"
        echo "  --add NAME DESC   Add a new topic"
        echo "  --remove N        Remove topic number N"
        exit 1
        ;;
esac
