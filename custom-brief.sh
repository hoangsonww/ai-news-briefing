#!/bin/bash
set -uo pipefail

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
  CLAUDE=""
fi

# Ensure we can run even if Claude Code is open
unset CLAUDECODE 2>/dev/null || true

mkdir -p "$LOG_DIR"

# -- Colors (auto-disable if not a terminal) -------------------
if [[ -t 1 ]]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  CYAN='\033[36m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  RED='\033[31m'
  MAGENTA='\033[35m'
  WHITE='\033[97m'
  RESET='\033[0m'
else
  BOLD='' DIM='' CYAN='' GREEN='' YELLOW='' RED='' MAGENTA='' WHITE='' RESET=''
fi

# -- CLI Engine Registry ---------------------------------------
SUPPORTED_CLIS="claude codex gemini copilot"

resolve_binary() {
  local cli="$1"
  case "$cli" in
    claude)
      for p in "${HOME}/.local/bin/claude" "${HOME}/.local/bin/claude.exe"; do
        if [ -x "$p" ]; then echo "$p"; return 0; fi
      done
      command -v claude 2>/dev/null && return 0
      return 1
      ;;
    codex)
      command -v codex 2>/dev/null && return 0
      return 1
      ;;
    gemini)
      command -v gemini 2>/dev/null && return 0
      return 1
      ;;
    copilot)
      if command -v gh >/dev/null 2>&1; then
        if gh extension list 2>/dev/null | grep -q copilot; then
          echo "gh"; return 0
        fi
      fi
      command -v copilot 2>/dev/null && return 0
      return 1
      ;;
    *) return 1 ;;
  esac
}

cli_display_name() {
  case "$1" in
    claude)  echo "Claude Code" ;;
    codex)   echo "OpenAI Codex" ;;
    gemini)  echo "Gemini CLI" ;;
    copilot) echo "GitHub Copilot" ;;
    *)       echo "$1" ;;
  esac
}

run_engine() {
  local cli="$1" binary="$2" prompt="$3" log="$4"
  local model="${AI_BRIEFING_MODEL:-opus}"

  case "$cli" in
    claude)
      "$binary" -p \
        --model "$model" \
        --dangerously-skip-permissions \
        "$prompt" 2>&1 | tee -a "$log"
      ;;
    codex)
      "$binary" -q --full-auto \
        "$prompt" 2>&1 | tee -a "$log"
      ;;
    gemini)
      "$binary" -p \
        "$prompt" 2>&1 | tee -a "$log"
      ;;
    copilot)
      if [ "$binary" = "gh" ]; then
        "$binary" copilot -p \
          "$prompt" 2>&1 | tee -a "$log"
      else
        "$binary" -p \
          "$prompt" 2>&1 | tee -a "$log"
      fi
      ;;
  esac
}

# -- Defaults --------------------------------------------------
TOPIC=""
CLI_ENGINE=""
PUBLISH_NOTION=false
PUBLISH_OBSIDIAN=false
PUBLISH_TEAMS=false
PUBLISH_SLACK=false

# -- Parse arguments -------------------------------------------
print_usage() {
  cat <<'EOF'
Usage: custom-brief.sh [OPTIONS]

Deep-research a topic and produce a comprehensive news briefing.

Options:
  --topic, -t TEXT        Topic to research (required in non-interactive mode)
  --cli, -c ENGINE        AI engine: claude, codex, gemini, copilot
  --notion, -n            Publish to Notion
  --obsidian, -o          Publish to Obsidian vault (requires AI_BRIEFING_OBSIDIAN_VAULT)
  --teams                 Publish to Microsoft Teams
  --slack                 Publish to Slack
  --help, -h              Show this help

Environment:
  AI_BRIEFING_CLI         Default engine (overridden by --cli)
  AI_BRIEFING_MODEL       Model name (default: opus)

If no arguments are given, enters interactive mode.

Examples:
  ./custom-brief.sh --topic "AI in healthcare" --cli codex --notion --obsidian --teams
  ./custom-brief.sh -t "quantum computing" -c gemini -n -o
  ./custom-brief.sh   # interactive mode
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --topic|-t)
      [[ $# -lt 2 ]] && { echo "ERROR: --topic requires a value" >&2; exit 1; }
      TOPIC="$2"; shift 2 ;;
    --cli|-c)
      [[ $# -lt 2 ]] && { echo "ERROR: --cli requires a value" >&2; exit 1; }
      CLI_ENGINE="$2"; shift 2 ;;
    --notion|-n)
      PUBLISH_NOTION=true; shift ;;
    --obsidian|-o)
      PUBLISH_OBSIDIAN=true; shift ;;
    --teams)
      PUBLISH_TEAMS=true; shift ;;
    --slack)
      PUBLISH_SLACK=true; shift ;;
    --help|-h)
      print_usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
  esac
done

# -- Banner ----------------------------------------------------
print_banner() {
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
}

# -- Interactive REPL (if no topic provided) -------------------
if [[ -z "$TOPIC" ]]; then
  print_banner
  echo -e "  ${MAGENTA}${BOLD}Interactive Mode${RESET}"
  echo ""

  # Topic
  echo -e "  ${DIM}--- Topic -------------------------------------------------${RESET}"
  echo -ne "  ${BOLD}What would you like to research?${RESET}\n  > "
  read -r TOPIC
  if [[ -z "$TOPIC" ]]; then
    echo -e "  ${RED}Error: topic cannot be empty.${RESET}" >&2
    exit 1
  fi
  echo ""
  # AI Engine
  echo -e "  ${DIM}--- AI Engine ---------------------------------------------${RESET}"
  idx=0
  default_idx=0
  default_cli=""
  for cli in $SUPPORTED_CLIS; do
    idx=$((idx + 1))
    label="$(cli_display_name "$cli")"
    # Pad label to fixed width
    padded="$(printf '%-16s' "$label")"
    if resolve_binary "$cli" >/dev/null 2>&1; then
      avail="${GREEN}available${RESET}"
      if [[ -z "$default_cli" ]]; then
        default_cli="$cli"
        default_idx=$idx
      fi
    else
      avail="${RED}not installed${RESET}"
    fi
    echo -e "    ${WHITE}${idx})${RESET} ${padded} ${avail}"
  done
  echo ""

  env_cli="${AI_BRIEFING_CLI:-}"
  if [[ -n "$env_cli" ]]; then
    # Find index of env-configured CLI
    idx=0
    for cli in $SUPPORTED_CLIS; do
      idx=$((idx + 1))
      if [[ "$cli" == "$env_cli" ]]; then default_idx=$idx; default_cli="$env_cli"; break; fi
    done
  fi

  echo -ne "  ${BOLD}Select [1-4, default=${default_idx}]:${RESET} "
  read -r engine_choice
  if [[ -z "$engine_choice" ]]; then
    CLI_ENGINE="$default_cli"
  else
    idx=0
    for cli in $SUPPORTED_CLIS; do
      idx=$((idx + 1))
      if [[ "$idx" == "$engine_choice" ]]; then CLI_ENGINE="$cli"; break; fi
    done
    if [[ -z "$CLI_ENGINE" ]]; then
      echo -e "  ${RED}Invalid selection.${RESET}" >&2
      exit 1
    fi
  fi
  echo ""

  # Publish destinations
  echo -e "  ${DIM}--- Publish -----------------------------------------------${RESET}"
  read -rp "    Notion?   [y/N]: " yn
  [[ "$yn" =~ ^[Yy] ]] && PUBLISH_NOTION=true
  read -rp "    Obsidian? [y/N]: " yn
  [[ "$yn" =~ ^[Yy] ]] && PUBLISH_OBSIDIAN=true
  read -rp "    Teams?    [y/N]: " yn
  [[ "$yn" =~ ^[Yy] ]] && PUBLISH_TEAMS=true
  read -rp "    Slack?  [y/N]: " yn
  [[ "$yn" =~ ^[Yy] ]] && PUBLISH_SLACK=true
  echo ""
fi

# -- Resolve engine (non-interactive fallback) -----------------
if [[ -z "$CLI_ENGINE" ]]; then
  CLI_ENGINE="${AI_BRIEFING_CLI:-claude}"
fi

ENGINE_BINARY=$(resolve_binary "$CLI_ENGINE" 2>/dev/null) || {
  echo -e "  ${RED}${BOLD}ERROR${RESET}  ${RED}Engine '$(cli_display_name "$CLI_ENGINE")' is not installed.${RESET}" >&2
  exit 1
}

# -- Determine if card JSON is needed --------------------------
PUBLISH_TEAMS_SLACK=false
if [[ "$PUBLISH_TEAMS" == "true" || "$PUBLISH_SLACK" == "true" ]]; then
  PUBLISH_TEAMS_SLACK=true
fi

# -- Build the prompt ------------------------------------------
LOG_FILE="$LOG_DIR/custom-$TIMESTAMP.log"
CARD_FILE="$LOG_DIR/custom-$TIMESTAMP-card.json"

PROMPT_TEMPLATE="$(cat "$SCRIPT_DIR/prompt-custom-brief.md")"

PROMPT="$(awk \
  -v topic="$TOPIC" \
  -v date="$DATE" \
  -v ts="$TIMESTAMP" \
  -v notion="$PUBLISH_NOTION" \
  -v obsidian="$PUBLISH_OBSIDIAN" \
  -v tslack="$PUBLISH_TEAMS_SLACK" \
  '{
    gsub(/\{\{TOPIC\}\}/, topic)
    gsub(/\{\{DATE\}\}/, date)
    gsub(/\{\{TIMESTAMP\}\}/, ts)
    gsub(/\{\{PUBLISH_NOTION\}\}/, notion)
    gsub(/\{\{PUBLISH_OBSIDIAN\}\}/, obsidian)
    gsub(/\{\{PUBLISH_TEAMS_SLACK\}\}/, tslack)
    print
  }' <<< "$PROMPT_TEMPLATE")"

# -- Helpers for styled boolean display ------------------------
flag_label() {
  if [[ "$1" == "true" ]]; then
    echo -e "${GREEN}yes${RESET}"
  else
    echo -e "${DIM}no${RESET}"
  fi
}

# -- Print run summary -----------------------------------------
print_banner
echo -e "  ${MAGENTA}${BOLD}Deep Research${RESET}"
echo ""
echo -e "  ${BOLD}Topic${RESET}     $TOPIC"
echo -e "  ${BOLD}Engine${RESET}    $(cli_display_name "$CLI_ENGINE") ${DIM}($ENGINE_BINARY)${RESET}"
echo -e "  ${BOLD}Notion${RESET}    $(flag_label "$PUBLISH_NOTION")"
echo -e "  ${BOLD}Obsidian${RESET}  $(flag_label "$PUBLISH_OBSIDIAN")"
echo -e "  ${BOLD}Teams${RESET}     $(flag_label "$PUBLISH_TEAMS")"
echo -e "  ${BOLD}Slack${RESET}     $(flag_label "$PUBLISH_SLACK")"
echo -e "  ${DIM}Log${RESET}       ${DIM}$LOG_FILE${RESET}"
echo ""
echo -e "  ${MAGENTA}Launching research agents via $(cli_display_name "$CLI_ENGINE")...${RESET}"
echo -e "  ${DIM}This may take a few minutes.${RESET}"
echo ""
echo -e "  ${DIM}================================================${RESET}"
echo ""

# -- Log header ------------------------------------------------
{
  echo "[$DATE $(date +%H:%M:%S)] Custom Brief -- Topic: $TOPIC"
  echo "[$DATE $(date +%H:%M:%S)] Engine=$CLI_ENGINE Notion=$PUBLISH_NOTION Obsidian=$PUBLISH_OBSIDIAN Teams=$PUBLISH_TEAMS Slack=$PUBLISH_SLACK"
} >> "$LOG_FILE"

# -- Run engine ------------------------------------------------
set +o pipefail
run_engine "$CLI_ENGINE" "$ENGINE_BINARY" "$PROMPT" "$LOG_FILE"
EXIT_CODE="${PIPESTATUS[0]:-$?}"
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

# -- Post-processing: Teams notification -----------------------
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

# -- Post-processing: Slack notification -----------------------
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

# -- Post-processing: Obsidian publishing ------------------
if [[ "$PUBLISH_OBSIDIAN" == "true" ]]; then
  OBSIDIAN_SCRIPT="$SCRIPT_DIR/scripts/publish-obsidian.sh"
  OBSIDIAN_FILE="$LOG_DIR/custom-$TIMESTAMP-obsidian.md"
  if [[ -f "$OBSIDIAN_SCRIPT" && -n "${AI_BRIEFING_OBSIDIAN_VAULT:-}" ]]; then
    if [[ -f "$OBSIDIAN_FILE" ]]; then
      echo -e "  ${DIM}Publishing to Obsidian...${RESET}"
      echo "[$DATE $(date +%H:%M:%S)] Publishing to Obsidian vault..." >> "$LOG_FILE"
      if bash "$OBSIDIAN_SCRIPT" --file "$OBSIDIAN_FILE"; then
        echo "[$DATE $(date +%H:%M:%S)] Obsidian publish complete." >> "$LOG_FILE"
        echo -e "  ${GREEN}Obsidian${RESET}  published"
      else
        echo "[$DATE $(date +%H:%M:%S)] Obsidian publish failed." >> "$LOG_FILE"
        echo -e "  ${RED}Obsidian${RESET}  failed" >&2
      fi
    else
      echo -e "  ${YELLOW}Obsidian${RESET}  skipped ${DIM}(no markdown file)${RESET}" >&2
      echo "[$DATE $(date +%H:%M:%S)] Obsidian skipped -- markdown file not found." >> "$LOG_FILE"
    fi
  else
    echo -e "  ${YELLOW}Obsidian${RESET}  skipped ${DIM}(vault not set)${RESET}" >&2
  fi
fi

echo ""
echo -e "  ${DIM}================================================${RESET}"
echo -e "  ${GREEN}${BOLD}Done.${RESET}  ${DIM}Log: $LOG_FILE${RESET}"
echo -e "  ${DIM}================================================${RESET}"
echo ""
