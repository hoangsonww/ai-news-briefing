#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

# Resolve Claude CLI path (supports macOS, Linux, and Windows Git Bash)
if [ -x "${HOME}/.local/bin/claude" ]; then
  CLAUDE="${HOME}/.local/bin/claude"
elif [ -x "${HOME}/.local/bin/claude.exe" ]; then
  CLAUDE="${HOME}/.local/bin/claude.exe"
elif command -v claude >/dev/null 2>&1; then
  CLAUDE="$(command -v claude)"
else
  echo "ERROR: Claude CLI not found. Install it at ~/.local/bin/claude" >&2
  exit 1
fi

# Ensure we can run even if Claude Code is open
unset CLAUDECODE 2>/dev/null || true

mkdir -p "$LOG_DIR"

# -- Colors (auto-disable if not a terminal) ---------------
if [[ -t 1 ]]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  CYAN='\033[36m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  RED='\033[31m'
  MAGENTA='\033[35m'
  RESET='\033[0m'
else
  BOLD='' DIM='' CYAN='' GREEN='' YELLOW='' RED='' MAGENTA='' RESET=''
fi

# -- Defaults ----------------------------------------------
TOPIC=""
PUBLISH_NOTION=false
PUBLISH_TEAMS=false
PUBLISH_SLACK=false

# -- Parse arguments ---------------------------------------
print_usage() {
  cat <<'EOF'
Usage: custom-brief.sh [OPTIONS]

Deep-research a topic and produce a comprehensive news briefing.

Options:
  --topic, -t TEXT    Topic to research (required in non-interactive mode)
  --notion, -n        Publish to Notion
  --teams             Publish to Microsoft Teams
  --slack             Publish to Slack
  --help, -h          Show this help

If no arguments are given, enters interactive mode.

Examples:
  ./custom-brief.sh --topic "AI in healthcare" --notion --teams
  ./custom-brief.sh -t "quantum computing" -n
  ./custom-brief.sh   # interactive mode
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --topic|-t)
      if [[ $# -lt 2 ]]; then echo "ERROR: --topic requires a value" >&2; exit 1; fi
      TOPIC="$2"
      shift 2
      ;;
    --notion|-n)
      PUBLISH_NOTION=true
      shift
      ;;
    --teams)
      PUBLISH_TEAMS=true
      shift
      ;;
    --slack)
      PUBLISH_SLACK=true
      shift
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

# -- Interactive REPL (if no topic provided) ---------------
if [[ -z "$TOPIC" ]]; then
  echo ""
  echo -e "  ${DIM} _____                                                                 _____ ${RESET}"
  echo -e "  ${DIM}( ___ )---------------------------------------------------------------( ___ )${RESET}"
  echo -e "  ${DIM} |   |                                                                 |   | ${RESET}"
  echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN}     _    ___   _   _                     ____       _       __  ${RESET}${DIM}|   | ${RESET}"
  echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN}    / \\  |_ _| | \\ | | _____      _____  | __ ) _ __(_) ___ / _| ${RESET}${DIM}|   | ${RESET}"
  echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN}   / _ \\  | |  |  \\| |/ _ \\ \\ /\\ / / __| |  _ \\| '__| |/ _ \\ |_  ${RESET}${DIM}|   | ${RESET}"
  echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN}  / ___ \\ | |  | |\\  |  __/\\ V  V /\\__ \\ | |_) | |  | |  __/  _| ${RESET}${DIM}|   | ${RESET}"
  echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN} /_/   \\_\\___| |_| \\_|\\___| \\_/\\_/ |___/ |____/|_|  |_|\\___|_|   ${RESET}${DIM}|   | ${RESET}"
  echo -e "  ${DIM} |___|                                                                 |___| ${RESET}"
  echo -e "  ${DIM}(_____)---------------------------------------------------------------(_____)${RESET}"
  echo ""
  echo -e "  ${MAGENTA}Interactive Mode${RESET}"
  echo ""
  echo -ne "  ${BOLD}Topic:${RESET} "
  read -r TOPIC
  if [[ -z "$TOPIC" ]]; then
    echo -e "  ${RED}Error: topic cannot be empty.${RESET}" >&2
    exit 1
  fi
  echo ""
  echo -e "  ${DIM}Publish to:${RESET}"
  read -rp "    Notion? [y/N]: " yn
  [[ "$yn" =~ ^[Yy] ]] && PUBLISH_NOTION=true
  read -rp "    Teams?  [y/N]: " yn
  [[ "$yn" =~ ^[Yy] ]] && PUBLISH_TEAMS=true
  read -rp "    Slack?  [y/N]: " yn
  [[ "$yn" =~ ^[Yy] ]] && PUBLISH_SLACK=true
  echo ""
fi

# -- Determine if card JSON is needed ----------------------
PUBLISH_TEAMS_SLACK=false
if [[ "$PUBLISH_TEAMS" == "true" || "$PUBLISH_SLACK" == "true" ]]; then
  PUBLISH_TEAMS_SLACK=true
fi

# -- Build the prompt --------------------------------------
LOG_FILE="$LOG_DIR/custom-$TIMESTAMP.log"
CARD_FILE="$LOG_DIR/custom-$TIMESTAMP-card.json"

PROMPT_TEMPLATE="$(cat "$SCRIPT_DIR/prompt-custom-brief.md")"

# Replace placeholders using awk for safe literal substitution.
# Bash parameter expansion treats & and \ specially in replacements,
# so awk gsub is safer for user-supplied topic strings.
PROMPT="$(awk \
  -v topic="$TOPIC" \
  -v date="$DATE" \
  -v ts="$TIMESTAMP" \
  -v notion="$PUBLISH_NOTION" \
  -v tslack="$PUBLISH_TEAMS_SLACK" \
  '{
    gsub(/\{\{TOPIC\}\}/, topic)
    gsub(/\{\{DATE\}\}/, date)
    gsub(/\{\{TIMESTAMP\}\}/, ts)
    gsub(/\{\{PUBLISH_NOTION\}\}/, notion)
    gsub(/\{\{PUBLISH_TEAMS_SLACK\}\}/, tslack)
    print
  }' <<< "$PROMPT_TEMPLATE")"

# -- Helpers for styled boolean display --------------------
flag_label() {
  if [[ "$1" == "true" ]]; then
    echo -e "${GREEN}yes${RESET}"
  else
    echo -e "${DIM}no${RESET}"
  fi
}

# -- Print run summary ------------------------------------
echo ""
echo -e "  ${DIM} _____                                                                 _____ ${RESET}"
echo -e "  ${DIM}( ___ )---------------------------------------------------------------( ___ )${RESET}"
echo -e "  ${DIM} |   |                                                                 |   | ${RESET}"
echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN}     _    ___   _   _                     ____       _       __  ${RESET}${DIM}|   | ${RESET}"
echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN}    / \\  |_ _| | \\ | | _____      _____  | __ ) _ __(_) ___ / _| ${RESET}${DIM}|   | ${RESET}"
echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN}   / _ \\  | |  |  \\| |/ _ \\ \\ /\\ / / __| |  _ \\| '__| |/ _ \\ |_  ${RESET}${DIM}|   | ${RESET}"
echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN}  / ___ \\ | |  | |\\  |  __/\\ V  V /\\__ \\ | |_) | |  | |  __/  _| ${RESET}${DIM}|   | ${RESET}"
echo -e "  ${DIM} |   |${RESET}${BOLD}${CYAN} /_/   \\_\\___| |_| \\_|\\___| \\_/\\_/ |___/ |____/|_|  |_|\\___|_|   ${RESET}${DIM}|   | ${RESET}"
echo -e "  ${DIM} |___|                                                                 |___| ${RESET}"
echo -e "  ${DIM}(_____)---------------------------------------------------------------(_____)${RESET}"
echo ""
echo -e "  ${MAGENTA}Deep Research${RESET}"
echo ""
echo -e "  ${BOLD}Topic${RESET}     $TOPIC"
echo -e "  ${BOLD}Notion${RESET}    $(flag_label "$PUBLISH_NOTION")"
echo -e "  ${BOLD}Teams${RESET}     $(flag_label "$PUBLISH_TEAMS")"
echo -e "  ${BOLD}Slack${RESET}     $(flag_label "$PUBLISH_SLACK")"
echo -e "  ${DIM}Log${RESET}       ${DIM}$LOG_FILE${RESET}"
echo ""
echo -e "  ${MAGENTA}Launching 5 parallel research agents...${RESET}"
echo -e "  ${DIM}This may take a few minutes.${RESET}"
echo ""
echo -e "  ${DIM}================================================${RESET}"
echo ""

# -- Log header --------------------------------------------
{
  echo "[$DATE $(date +%H:%M:%S)] Custom Brief -- Topic: $TOPIC"
  echo "[$DATE $(date +%H:%M:%S)] Notion=$PUBLISH_NOTION Teams=$PUBLISH_TEAMS Slack=$PUBLISH_SLACK"
} >> "$LOG_FILE"

# -- Run Claude --------------------------------------------
# Tee to both stdout (user sees briefing) and log file.
# Temporarily disable pipefail so tee doesn't mask Claude's exit code,
# then capture Claude's exit code via PIPESTATUS[0].
set +o pipefail
"$CLAUDE" -p \
    --model opus \
    --dangerously-skip-permissions \
    "$PROMPT" 2>&1 | tee -a "$LOG_FILE"
EXIT_CODE="${PIPESTATUS[0]}"
set -o pipefail

echo "" >> "$LOG_FILE"

if [[ "$EXIT_CODE" -ne 0 ]]; then
  echo "[$DATE $(date +%H:%M:%S)] Custom brief FAILED with exit code $EXIT_CODE." >> "$LOG_FILE"
  echo ""
  echo -e "  ${RED}${BOLD}FAILED${RESET}  ${RED}Custom brief failed (exit code $EXIT_CODE)${RESET}"
  echo -e "  ${DIM}Log: $LOG_FILE${RESET}"
  exit "$EXIT_CODE"
fi

echo "[$DATE $(date +%H:%M:%S)] Custom brief complete." >> "$LOG_FILE"

# -- Post-processing: Teams notification -------------------
if [[ "$PUBLISH_TEAMS" == "true" ]]; then
  TEAMS_SCRIPT="$SCRIPT_DIR/scripts/notify-teams.sh"
  if [[ -f "$TEAMS_SCRIPT" && -n "${AI_BRIEFING_TEAMS_WEBHOOK:-}" ]]; then
    if [[ -f "$CARD_FILE" ]]; then
      echo ""
      echo -e "  ${DIM}Sending to Teams...${RESET}"
      echo "[$DATE $(date +%H:%M:%S)] Sending Teams notification..." >> "$LOG_FILE"
      if bash "$TEAMS_SCRIPT" --all --card-file "$CARD_FILE"; then
        echo "[$DATE $(date +%H:%M:%S)] Teams notification sent." >> "$LOG_FILE"
        echo -e "  ${GREEN}Teams${RESET}     sent"
      else
        echo "[$DATE $(date +%H:%M:%S)] Teams notification failed." >> "$LOG_FILE"
        echo -e "  ${RED}Teams${RESET}     failed" >&2
      fi
    else
      echo -e "  ${YELLOW}Teams${RESET}     skipped ${DIM}(no card JSON)${RESET}" >&2
      echo "[$DATE $(date +%H:%M:%S)] Teams skipped -- card file not found." >> "$LOG_FILE"
    fi
  else
    echo -e "  ${YELLOW}Teams${RESET}     skipped ${DIM}(webhook not set)${RESET}" >&2
  fi
fi

# -- Post-processing: Slack notification -------------------
if [[ "$PUBLISH_SLACK" == "true" ]]; then
  SLACK_SCRIPT="$SCRIPT_DIR/scripts/notify-slack.sh"
  if [[ -f "$SLACK_SCRIPT" && -n "${AI_BRIEFING_SLACK_WEBHOOK:-}" ]]; then
    if [[ -f "$CARD_FILE" ]]; then
      echo -e "  ${DIM}Sending to Slack...${RESET}"
      echo "[$DATE $(date +%H:%M:%S)] Sending Slack notification..." >> "$LOG_FILE"
      if bash "$SLACK_SCRIPT" --all --card-file "$CARD_FILE"; then
        echo "[$DATE $(date +%H:%M:%S)] Slack notification sent." >> "$LOG_FILE"
        echo -e "  ${GREEN}Slack${RESET}     sent"
      else
        echo "[$DATE $(date +%H:%M:%S)] Slack notification failed." >> "$LOG_FILE"
        echo -e "  ${RED}Slack${RESET}     failed" >&2
      fi
    else
      echo -e "  ${YELLOW}Slack${RESET}     skipped ${DIM}(no card JSON)${RESET}" >&2
      echo "[$DATE $(date +%H:%M:%S)] Slack skipped -- card file not found." >> "$LOG_FILE"
    fi
  else
    echo -e "  ${YELLOW}Slack${RESET}     skipped ${DIM}(webhook not set)${RESET}" >&2
  fi
fi

echo ""
echo -e "  ${DIM}================================================${RESET}"
echo -e "  ${GREEN}${BOLD}Done.${RESET}  ${DIM}Log: $LOG_FILE${RESET}"
echo -e "  ${DIM}================================================${RESET}"
echo ""
