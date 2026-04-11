#!/bin/bash
# Tests for daily briefing pipeline — non-blocking (no Claude, no webhooks)
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
echo -e "  ${MAG}${B}  daily briefing tests${R}"
echo -e "  ${MAG}${B}================================================${R}"

# -- File existence ----------------------------------------
section "File existence"
for f in briefing.sh briefing.ps1 prompt.md install-task.ps1 commands/ai-news-briefing.md; do
  [ -f "$SCRIPT_DIR/$f" ] && pass "$f exists" || fail "$f exists"
done

# -- Bash syntax -------------------------------------------
section "Bash syntax"
if bash -n "$SCRIPT_DIR/briefing.sh" 2>/dev/null; then
  pass "briefing.sh valid bash syntax"
else
  fail "briefing.sh valid bash syntax"
fi

# -- Prompt structure (prompt.md) --------------------------
section "Prompt structure (prompt.md)"
prompt=$(cat "$SCRIPT_DIR/prompt.md")
assert_contains "$prompt" "Step 0" "prompt: has Step 0 (covered stories)"
assert_contains "$prompt" "Step 1" "prompt: has Step 1 (search)"
assert_contains "$prompt" "Step 2" "prompt: has Step 2 (compile)"
assert_contains "$prompt" "Step 3" "prompt: has Step 3 (write to Notion)"
assert_contains "$prompt" "Step 4" "prompt: has Step 4 (card JSON)"
assert_contains "$prompt" "Step 5" "prompt: has Step 5 (Obsidian markdown)"
assert_contains "$prompt" "Step 6" "prompt: has Step 6 (covered stories update)"
assert_contains "$prompt" "856794cc-d871-4a95-be2d-2a1600920a19" "prompt: has correct data_source_id"
assert_contains "$prompt" "covered-stories.txt" "prompt: references dedup file"
assert_contains "$prompt" "mcp__notion__notion-search" "prompt: uses Notion search MCP"
assert_contains "$prompt" "mcp__notion__notion-create-pages" "prompt: uses Notion create MCP"
assert_contains "$prompt" "Adaptive Card" "prompt: has card template"

# -- Prompt topics -----------------------------------------
section "Topic coverage (prompt.md)"
for topic in "Claude Code" "OpenAI" "AI Coding IDEs" "Agentic AI" "AI Industry" "Open Source AI" "AI Startups" "AI Policy" "Dev Tools"; do
  assert_contains "$prompt" "$topic" "prompt: covers $topic"
done

# -- Changelog URLs ----------------------------------------
section "Changelog URLs (prompt.md)"
for url in "code.claude.com" "support.claude.com" "developers.openai.com" "help.openai.com" "gemini.google" "github.blog/changelog" "cursor.com/changelog" "sdk.vercel.ai"; do
  assert_contains "$prompt" "$url" "prompt: checks $url changelog"
done

# -- Skill structure (commands/ai-news-briefing.md) --------
section "Skill structure"
skill=$(cat "$SCRIPT_DIR/commands/ai-news-briefing.md")
assert_contains "$skill" "description:" "skill: has frontmatter"
assert_contains "$skill" "Step 0" "skill: has Step 0"
assert_contains "$skill" "Step 1" "skill: has Step 1"
assert_contains "$skill" "Step 3" "skill: has Step 3"
assert_contains "$skill" "notion-create-pages" "skill: references Notion create"
assert_contains "$skill" "covered-stories.txt" "skill: references dedup file"

# -- Entry script structure (briefing.sh) ------------------
section "Entry script (briefing.sh)"
entry=$(cat "$SCRIPT_DIR/briefing.sh")
assert_contains "$entry" "fallback" "briefing.sh: uses fallback chain (explicit error handling)"
assert_contains "$entry" "prompt.md" "briefing.sh: reads prompt.md"
assert_contains "$entry" "claude" "briefing.sh: invokes Claude CLI"
assert_contains "$entry" "notify-teams" "briefing.sh: calls Teams notifier"
assert_contains "$entry" "notify-slack" "briefing.sh: calls Slack notifier"
assert_contains "$entry" "CLAUDECODE" "briefing.sh: clears CLAUDECODE env"
assert_contains "$entry" "logs/" "briefing.sh: uses logs directory"

# -- Entry script structure (briefing.ps1) -----------------
section "Entry script (briefing.ps1)"
ps_entry=$(cat "$SCRIPT_DIR/briefing.ps1")
assert_contains "$ps_entry" "StrictMode" "briefing.ps1: uses strict mode"
assert_contains "$ps_entry" "prompt.md" "briefing.ps1: reads prompt.md"
assert_contains "$ps_entry" "claude" "briefing.ps1: invokes Claude CLI"
assert_contains "$ps_entry" "notify-teams" "briefing.ps1: calls Teams notifier"
assert_contains "$ps_entry" "notify-slack" "briefing.ps1: calls Slack notifier"
assert_contains "$ps_entry" "CLAUDECODE" "briefing.ps1: clears CLAUDECODE env"

# -- Covered stories file ----------------------------------
section "Deduplication file"
COVERED="$SCRIPT_DIR/logs/covered-stories.txt"
if [ -f "$COVERED" ]; then
  pass "covered-stories.txt exists"
  line_count=$(wc -l < "$COVERED")
  if [[ "$line_count" -gt 0 ]]; then
    pass "covered-stories.txt has $line_count entries"
  else
    fail "covered-stories.txt is empty"
  fi
  # Check format: YYYY-MM-DD | headline
  if head -1 "$COVERED" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} \|'; then
    pass "covered-stories.txt format correct (date | headline)"
  else
    fail "covered-stories.txt format (expected 'YYYY-MM-DD | headline')"
  fi
else
  pass "covered-stories.txt not yet created (OK for fresh install)"
fi

# -- Obsidian integration (prompt.md) ----------------------
section "Obsidian integration (prompt.md)"
assert_contains "$prompt" "Obsidian" "prompt: mentions Obsidian"
assert_contains "$prompt" "obsidian.md" "prompt: references obsidian.md output file"
assert_contains "$prompt" "[[" "prompt: uses [[wikilinks]] syntax"
assert_contains "$prompt" "frontmatter" "prompt: requires YAML frontmatter"

# -- Obsidian integration (briefing.sh) --------------------
section "Obsidian integration (briefing.sh)"
assert_contains "$entry" "publish-obsidian" "briefing.sh: calls Obsidian publisher"
assert_contains "$entry" "OBSIDIAN_VAULT" "briefing.sh: checks vault env var"
assert_contains "$entry" "obsidian.md" "briefing.sh: references obsidian.md file"

# -- Obsidian integration (briefing.ps1) -------------------
section "Obsidian integration (briefing.ps1)"
assert_contains "$ps_entry" "publish-obsidian" "briefing.ps1: calls Obsidian publisher"
assert_contains "$ps_entry" "OBSIDIAN_VAULT" "briefing.ps1: checks vault env var"
assert_contains "$ps_entry" "obsidian.md" "briefing.ps1: references obsidian.md file"

# -- Obsidian publish script existence ---------------------
section "Obsidian publish scripts"
[ -f "$SCRIPT_DIR/scripts/publish-obsidian.sh" ] && pass "publish-obsidian.sh exists" || fail "publish-obsidian.sh exists"
[ -x "$SCRIPT_DIR/scripts/publish-obsidian.sh" ] && pass "publish-obsidian.sh is executable" || fail "publish-obsidian.sh is executable"
[ -f "$SCRIPT_DIR/scripts/publish-obsidian.ps1" ] && pass "publish-obsidian.ps1 exists" || fail "publish-obsidian.ps1 exists"
[ -f "$SCRIPT_DIR/scripts/test-obsidian.sh" ] && pass "test-obsidian.sh exists" || fail "test-obsidian.sh exists"
[ -x "$SCRIPT_DIR/scripts/test-obsidian.sh" ] && pass "test-obsidian.sh is executable" || fail "test-obsidian.sh is executable"
[ -f "$SCRIPT_DIR/scripts/test-obsidian.ps1" ] && pass "test-obsidian.ps1 exists" || fail "test-obsidian.ps1 exists"

# -- Obsidian publish script syntax ------------------------
section "Obsidian script syntax"
if bash -n "$SCRIPT_DIR/scripts/publish-obsidian.sh" 2>/dev/null; then
  pass "publish-obsidian.sh valid bash syntax"
else
  fail "publish-obsidian.sh valid bash syntax"
fi
if bash -n "$SCRIPT_DIR/scripts/test-obsidian.sh" 2>/dev/null; then
  pass "test-obsidian.sh valid bash syntax"
else
  fail "test-obsidian.sh valid bash syntax"
fi

# -- Obsidian publish script structure ---------------------
section "Obsidian publish script structure"
pub_obs=$(cat "$SCRIPT_DIR/scripts/publish-obsidian.sh")
assert_contains "$pub_obs" "set -euo pipefail" "publish-obsidian.sh: uses strict mode"
assert_contains "$pub_obs" "AI-News-Briefings" "publish-obsidian.sh: uses briefings subdirectory"
assert_contains "$pub_obs" "Topics" "publish-obsidian.sh: uses topics subdirectory"
assert_contains "$pub_obs" "[[" "publish-obsidian.sh: extracts wikilinks"
assert_contains "$pub_obs" "type: topic" "publish-obsidian.sh: creates YAML topic type for stubs"
assert_contains "$pub_obs" "OBSIDIAN_VAULT" "publish-obsidian.sh: reads vault env var"

# -- Obsidian skill references -----------------------------
section "Obsidian in skill files"
assert_contains "$skill" "Obsidian" "daily skill: mentions Obsidian"

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
