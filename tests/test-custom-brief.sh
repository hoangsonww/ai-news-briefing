#!/bin/bash
# Tests for custom-brief.sh — non-blocking (no Claude, no webhooks, no Notion)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CUSTOM_BRIEF="$SCRIPT_DIR/custom-brief.sh"
PROMPT_TEMPLATE="$SCRIPT_DIR/prompt-custom-brief.md"

PASS=0
FAIL=0

# -- Colors (auto-disable if piped) --
if [[ -t 1 ]]; then
  B='\033[1m' D='\033[2m' R='\033[0m'
  GRN='\033[32m' RED='\033[31m' CYN='\033[36m' YLW='\033[33m' MAG='\033[35m'
else
  B='' D='' R='' GRN='' RED='' CYN='' YLW='' MAG=''
fi

pass() { PASS=$((PASS + 1)); echo -e "  ${GRN}PASS${R}  $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "  ${RED}FAIL${R}  $1"; }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 ${D}(expected '$2', got '$1')${R}"; fi; }
assert_contains() { if echo "$1" | grep -qF -- "$2"; then pass "$3"; else fail "$3 ${D}(missing '$2')${R}"; fi; }
section() { echo ""; echo -e "  ${CYN}${B}$1${R}"; }

echo ""
echo -e "  ${MAG}${B}================================================${R}"
echo -e "  ${MAG}${B}  custom-brief.sh tests${R}"
echo -e "  ${MAG}${B}================================================${R}"

# -- File existence ----------------------------------------
section "File existence"
[ -f "$CUSTOM_BRIEF" ] && pass "custom-brief.sh exists" || fail "custom-brief.sh exists"
[ -x "$CUSTOM_BRIEF" ] && pass "custom-brief.sh is executable" || fail "custom-brief.sh is executable"
[ -f "$PROMPT_TEMPLATE" ] && pass "prompt-custom-brief.md exists" || fail "prompt-custom-brief.md exists"
[ -f "$SCRIPT_DIR/commands/custom-brief.md" ] && pass "commands/custom-brief.md exists" || fail "commands/custom-brief.md exists"

# -- Bash syntax -------------------------------------------
echo ""
section "Bash syntax"
if bash -n "$CUSTOM_BRIEF" 2>/dev/null; then
  pass "custom-brief.sh valid bash syntax"
else
  fail "custom-brief.sh valid bash syntax"
fi

# -- Help flag ---------------------------------------------
echo ""
section "Help flag"
help_output=$(bash "$CUSTOM_BRIEF" --help 2>&1) || true
assert_contains "$help_output" "Usage:" "help: shows usage"
assert_contains "$help_output" "--topic" "help: mentions --topic"
assert_contains "$help_output" "--notion" "help: mentions --notion"
assert_contains "$help_output" "--teams" "help: mentions --teams"
assert_contains "$help_output" "--slack" "help: mentions --slack"

# -- Short help flag ---------------------------------------
help_short=$(bash "$CUSTOM_BRIEF" -h 2>&1) || true
assert_contains "$help_short" "Usage:" "short help: -h shows usage"

# -- Missing --topic value ---------------------------------
echo ""
section "Arg validation"
err_output=$(bash "$CUSTOM_BRIEF" --topic 2>&1) || true
exit_code=$?
assert_contains "$err_output" "requires a value" "missing --topic value: shows error"

# -- Unknown option ----------------------------------------
err_output=$(bash "$CUSTOM_BRIEF" --bogus 2>&1) || true
assert_contains "$err_output" "Unknown option" "unknown option: shows error"

# -- Template placeholder presence -------------------------
echo ""
section "Prompt template structure"
tmpl=$(cat "$PROMPT_TEMPLATE")
assert_contains "$tmpl" '{{TOPIC}}' "template: has {{TOPIC}} placeholder"
assert_contains "$tmpl" '{{DATE}}' "template: has {{DATE}} placeholder"
assert_contains "$tmpl" '{{TIMESTAMP}}' "template: has {{TIMESTAMP}} placeholder"
assert_contains "$tmpl" '{{PUBLISH_NOTION}}' "template: has {{PUBLISH_NOTION}} placeholder"
assert_contains "$tmpl" '{{PUBLISH_TEAMS_SLACK}}' "template: has {{PUBLISH_TEAMS_SLACK}} placeholder"
assert_contains "$tmpl" "Phase 1" "template: has Phase 1 (Broad Discovery)"
assert_contains "$tmpl" "Phase 2" "template: has Phase 2 (Deep Dive)"
assert_contains "$tmpl" "Phase 3" "template: has Phase 3 (Compile)"
assert_contains "$tmpl" "Agent 1" "template: defines Agent 1"
assert_contains "$tmpl" "Agent 5" "template: defines Agent 5"
assert_contains "$tmpl" "Adaptive Card" "template: has card template"
assert_contains "$tmpl" "clickable source link" "template: requires citations"

# -- Template substitution via awk -------------------------
echo ""
section "Template substitution"
test_topic="AI regulation in the EU (2026)"
result=$(awk \
  -v topic="$test_topic" \
  -v date="2026-04-01" \
  -v ts="2026-04-01-090000" \
  -v notion="true" \
  -v tslack="false" \
  '{
    gsub(/\{\{TOPIC\}\}/, topic)
    gsub(/\{\{DATE\}\}/, date)
    gsub(/\{\{TIMESTAMP\}\}/, ts)
    gsub(/\{\{PUBLISH_NOTION\}\}/, notion)
    gsub(/\{\{PUBLISH_TEAMS_SLACK\}\}/, tslack)
    print
  }' <<< "Topic: {{TOPIC}} Date: {{DATE}} Notion: {{PUBLISH_NOTION}}")

assert_contains "$result" "AI regulation in the EU" "awk substitution: topic injected"
assert_contains "$result" "(2026)" "awk substitution: parens preserved in topic"
assert_contains "$result" "2026-04-01" "awk substitution: replaces {{DATE}}"
assert_contains "$result" "Notion: true" "awk substitution: replaces {{PUBLISH_NOTION}}"

# Test no leftover placeholders
leftover=$(awk \
  -v topic="test" \
  -v date="2026-04-01" \
  -v ts="2026-04-01-090000" \
  -v notion="false" \
  -v tslack="true" \
  '{
    gsub(/\{\{TOPIC\}\}/, topic)
    gsub(/\{\{DATE\}\}/, date)
    gsub(/\{\{TIMESTAMP\}\}/, ts)
    gsub(/\{\{PUBLISH_NOTION\}\}/, notion)
    gsub(/\{\{PUBLISH_TEAMS_SLACK\}\}/, tslack)
    print
  }' "$PROMPT_TEMPLATE" | grep -c '{{' || true)
assert_eq "$leftover" "0" "awk substitution: no leftover {{}} placeholders"

# -- Interactive skill structure ---------------------------
echo ""
section "Interactive skill (commands/custom-brief.md)"
skill=$(cat "$SCRIPT_DIR/commands/custom-brief.md")
assert_contains "$skill" "description:" "skill: has frontmatter description"
assert_contains "$skill" "Step 0" "skill: has Step 0 (Gather Parameters)"
assert_contains "$skill" "Step 1" "skill: has Step 1 (Broad Discovery)"
assert_contains "$skill" "Agent 1" "skill: defines parallel agents"
assert_contains "$skill" "mcp__notion__notion-create-pages" "skill: uses Notion MCP"
assert_contains "$skill" "856794cc-d871-4a95-be2d-2a1600920a19" "skill: has correct data_source_id"
assert_contains "$skill" "Quality Checklist" "skill: has quality checklist"

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
