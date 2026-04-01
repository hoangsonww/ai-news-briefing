#!/bin/bash
# Tests for notification pipeline — non-blocking (no webhooks, no Slack/Teams)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0

if [[ -t 1 ]]; then
  B='\033[1m' D='\033[2m' R='\033[0m'
  GRN='\033[32m' RED='\033[31m' CYN='\033[36m' YLW='\033[33m' MAG='\033[35m'
else
  B='' D='' R='' GRN='' RED='' CYN='' YLW='' MAG=''
fi

pass() { PASS=$((PASS + 1)); echo -e "  ${GRN}PASS${R}  $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "  ${RED}FAIL${R}  $1"; }
assert_contains() { if echo "$1" | grep -qF -- "$2"; then pass "$3"; else fail "$3 ${D}(missing '$2')${R}"; fi; }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 ${D}(expected '$2', got '$1')${R}"; fi; }
section() { echo ""; echo -e "  ${CYN}${B}$1${R}"; }

echo ""
echo -e "  ${MAG}${B}================================================${R}"
echo -e "  ${MAG}${B}  notification pipeline tests${R}"
echo -e "  ${MAG}${B}================================================${R}"

# -- Script existence --------------------------------------
section "Script existence"
for f in scripts/notify-teams.sh scripts/notify-teams.ps1 scripts/notify-slack.sh scripts/notify-slack.ps1 scripts/teams-to-slack.py; do
  [ -f "$SCRIPT_DIR/$f" ] && pass "$f exists" || fail "$f exists"
done

# -- Bash syntax -------------------------------------------
section "Bash syntax"
for f in scripts/notify-teams.sh scripts/notify-slack.sh; do
  if bash -n "$SCRIPT_DIR/$f" 2>/dev/null; then
    pass "$f valid bash syntax"
  else
    fail "$f valid bash syntax"
  fi
done

# -- Python syntax -----------------------------------------
section "Python syntax"
if python3 -c "
import py_compile, sys
py_compile.compile(sys.argv[1], doraise=True)
" "$SCRIPT_DIR/scripts/teams-to-slack.py" 2>/dev/null; then
  pass "teams-to-slack.py valid Python syntax"
else
  fail "teams-to-slack.py valid Python syntax"
fi

# -- Card JSON validation ----------------------------------
section "Card JSON validation"
CARD_DIR="$SCRIPT_DIR/logs"
card_count=0
card_valid=0
card_invalid=0

for card in "$CARD_DIR"/*-card.json; do
  [ -f "$card" ] || continue
  card_count=$((card_count + 1))
  basename=$(basename "$card")
  if python3 -m json.tool "$card" > /dev/null 2>&1; then
    card_valid=$((card_valid + 1))
  else
    card_invalid=$((card_invalid + 1))
    fail "$basename: invalid JSON"
  fi
done

if [[ "$card_count" -gt 0 ]]; then
  pass "found $card_count card JSON files"
  if [[ "$card_invalid" -eq 0 ]]; then
    pass "all $card_valid cards are valid JSON"
  fi
else
  pass "no card files yet (OK for fresh install)"
fi

# -- Card structure (latest card) --------------------------
section "Card structure (latest card)"
LATEST_CARD=$(ls -t "$CARD_DIR"/*-card.json 2>/dev/null | head -1)
if [[ -n "$LATEST_CARD" && -f "$LATEST_CARD" ]]; then
  card_content=$(cat "$LATEST_CARD")
  assert_contains "$card_content" '"type": "message"' "card: has message envelope"
  assert_contains "$card_content" '"contentType": "application/vnd.microsoft.card.adaptive"' "card: has adaptive card content type"
  assert_contains "$card_content" '"type": "AdaptiveCard"' "card: has AdaptiveCard type"
  assert_contains "$card_content" '"version": "1.4"' "card: Adaptive Card v1.4"
  assert_contains "$card_content" '"msteams"' "card: has msteams width config"
  assert_contains "$card_content" '"Action.OpenUrl"' "card: has Notion action button"
  assert_contains "$card_content" "notion.so" "card: action links to Notion"

  # Size check (Teams limit is 28KB)
  card_size=$(wc -c < "$LATEST_CARD")
  if [[ "$card_size" -lt 28000 ]]; then
    pass "card size ${card_size}B (under 28KB Teams limit)"
  else
    fail "card size ${card_size}B (exceeds 28KB Teams limit)"
  fi

  # Check header structure
  assert_contains "$card_content" '"style": "emphasis"' "card: header has emphasis style"
  assert_contains "$card_content" '"bleed": true' "card: header has bleed"
  assert_contains "$card_content" '"ColumnSet"' "card: header uses ColumnSet"
  assert_contains "$card_content" "AI Daily Briefing" "card: header title present"

  # Check sources section
  assert_contains "$card_content" '**Sources**' "card: has Sources section"

  # Check bullets are individual TextBlocks (not combined)
  bullet_count=$(grep -c '"- ' "$LATEST_CARD" || true)
  if [[ "$bullet_count" -gt 0 ]]; then
    pass "card: has $bullet_count bullet TextBlocks"
  else
    fail "card: no bullet TextBlocks found"
  fi
else
  pass "no card files to validate structure (OK for fresh install)"
fi

# -- Teams-to-Slack converter ------------------------------
section "Teams-to-Slack converter"
if [[ -n "$LATEST_CARD" && -f "$LATEST_CARD" ]]; then
  CONVERTER="$SCRIPT_DIR/scripts/teams-to-slack.py"
  slack_output=$(python3 "$CONVERTER" "$LATEST_CARD" 2>&1)
  conv_exit=$?
  if [[ "$conv_exit" -eq 0 ]]; then
    pass "converter: processes latest card (exit 0)"
    # Validate output is JSON
    if echo "$slack_output" | python3 -m json.tool > /dev/null 2>&1; then
      pass "converter: output is valid JSON"
    else
      fail "converter: output is not valid JSON"
    fi
    assert_contains "$slack_output" '"type": "header"' "converter: has Slack header block"
    assert_contains "$slack_output" '"type": "divider"' "converter: has Slack divider"
    assert_contains "$slack_output" '"type": "section"' "converter: has Slack sections"
    assert_contains "$slack_output" '"type": "actions"' "converter: has Slack action button"
    assert_contains "$slack_output" "Open Full Briefing in Notion" "converter: Notion button text"
  else
    fail "converter: failed with exit code $conv_exit"
  fi
else
  pass "no card to convert (OK for fresh install)"
fi

# -- notify-teams.sh validation logic ----------------------
section "notify-teams.sh arguments"

# No webhook set -> should fail
unset AI_BRIEFING_TEAMS_WEBHOOK 2>/dev/null || true
err=$(bash "$SCRIPT_DIR/scripts/notify-teams.sh" 2>&1) || true
assert_contains "$err" "No webhook URL" "teams: errors when no webhook set"

# Unknown option -> should fail
err=$(AI_BRIEFING_TEAMS_WEBHOOK="http://test" bash "$SCRIPT_DIR/scripts/notify-teams.sh" --bogus 2>&1) || true
assert_contains "$err" "Unknown option" "teams: errors on unknown option"

# Missing card file -> should fail
err=$(AI_BRIEFING_TEAMS_WEBHOOK="http://test" bash "$SCRIPT_DIR/scripts/notify-teams.sh" --card-file /nonexistent/file.json 2>&1) || true
assert_contains "$err" "not found" "teams: errors when card file missing"

# -- notify-slack.sh argument handling ---------------------
section "notify-slack.sh arguments"

unset AI_BRIEFING_SLACK_WEBHOOK 2>/dev/null || true
err=$(bash "$SCRIPT_DIR/scripts/notify-slack.sh" 2>&1) || true
assert_contains "$err" "No webhook URL" "slack: errors when no webhook set"

err=$(AI_BRIEFING_SLACK_WEBHOOK="http://test" bash "$SCRIPT_DIR/scripts/notify-slack.sh" --bogus 2>&1) || true
assert_contains "$err" "Unknown option" "slack: errors on unknown option"

err=$(AI_BRIEFING_SLACK_WEBHOOK="http://test" bash "$SCRIPT_DIR/scripts/notify-slack.sh" --card-file /nonexistent/file.json 2>&1) || true
assert_contains "$err" "not found" "slack: errors when card file missing"

# -- Summary -----------------------------------------------
echo ""
echo -e "  ${D}================================================${R}"
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "  ${GRN}${B}ALL PASSED${R}  ${GRN}$PASS tests${R}"
else
  echo -e "  ${RED}${B}$FAIL FAILED${R}  ${D}($PASS passed)${R}"
fi
echo -e "  ${D}================================================${R}"
echo ""

exit "$FAIL"
