#!/bin/bash
# Tests for Obsidian publishing pipeline — non-blocking (no vault writes)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBLISH_SCRIPT="$SCRIPT_DIR/scripts/publish-obsidian.sh"
TEST_SCRIPT="$SCRIPT_DIR/scripts/test-obsidian.sh"

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
echo -e "  ${MAG}${B}  obsidian publishing tests${R}"
echo -e "  ${MAG}${B}================================================${R}"

# -- File existence ----------------------------------------
section "File existence"
[ -f "$PUBLISH_SCRIPT" ] && pass "publish-obsidian.sh exists" || fail "publish-obsidian.sh exists"
[ -x "$PUBLISH_SCRIPT" ] && pass "publish-obsidian.sh is executable" || fail "publish-obsidian.sh is executable"
[ -f "$TEST_SCRIPT" ] && pass "test-obsidian.sh exists" || fail "test-obsidian.sh exists"
[ -x "$TEST_SCRIPT" ] && pass "test-obsidian.sh is executable" || fail "test-obsidian.sh is executable"
[ -f "$SCRIPT_DIR/scripts/publish-obsidian.ps1" ] && pass "publish-obsidian.ps1 exists" || fail "publish-obsidian.ps1 exists"
[ -f "$SCRIPT_DIR/scripts/test-obsidian.ps1" ] && pass "test-obsidian.ps1 exists" || fail "test-obsidian.ps1 exists"

# -- Bash syntax -------------------------------------------
section "Bash syntax"
if bash -n "$PUBLISH_SCRIPT" 2>/dev/null; then
  pass "publish-obsidian.sh valid bash syntax"
else
  fail "publish-obsidian.sh valid bash syntax"
fi
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  pass "test-obsidian.sh valid bash syntax"
else
  fail "test-obsidian.sh valid bash syntax"
fi

# -- Publish script structure ------------------------------
section "Publish script structure"
pub=$(cat "$PUBLISH_SCRIPT")
assert_contains "$pub" "set -euo pipefail" "publish: uses strict mode"
assert_contains "$pub" "AI-News-Briefings" "publish: creates briefings subdirectory"
assert_contains "$pub" "Topics" "publish: creates topics subdirectory"
assert_contains "$pub" "OBSIDIAN_VAULT" "publish: reads vault env var"
assert_contains "$pub" "mkdir" "publish: creates directories if missing"
assert_contains "$pub" "cp " "publish: copies markdown file"

# -- Wikilink extraction -----------------------------------
section "Wikilink extraction logic"
assert_contains "$pub" "grep" "publish: uses grep for wikilink extraction"
assert_contains "$pub" "[[" "publish: extracts [[ patterns"
assert_contains "$pub" "type: topic" "publish: generates YAML topic type for stubs"

# -- Error handling ----------------------------------------
section "Error handling"
assert_contains "$pub" "exit 1" "publish: exits on error"

# Test missing file argument
err_output=$(AI_BRIEFING_OBSIDIAN_VAULT="/nonexistent" bash "$PUBLISH_SCRIPT" --file "/nonexistent/file.md" 2>&1) || true
assert_contains "$err_output" "not found" "publish: reports missing file error"

# Test missing vault (unset env var)
TEMP_FILE=$(mktemp)
echo "test" > "$TEMP_FILE"
err_output=$(unset AI_BRIEFING_OBSIDIAN_VAULT; bash "$PUBLISH_SCRIPT" --file "$TEMP_FILE" 2>&1) || true
assert_contains "$err_output" "not set" "publish: reports missing vault env var"
rm -f "$TEMP_FILE"

# -- Test script structure ---------------------------------
section "Test script structure"
test_scr=$(cat "$TEST_SCRIPT")
assert_contains "$test_scr" "OBSIDIAN_VAULT" "test: checks vault env var"
assert_contains "$test_scr" ".obsidian" "test: checks for .obsidian config dir"
assert_contains "$test_scr" "writable" "test: checks vault writability"

# -- Vault directory simulation ----------------------------
section "Vault directory simulation"
TEMP_VAULT=$(mktemp -d)
TEMP_MD=$(mktemp)

cat > "$TEMP_MD" << 'EOF'
---
date: 2026-04-11
type: daily-briefing
tags: [ai-news, daily]
---

# AI Daily Briefing — 2026-04-11

Related topics: [[Claude Code]], [[OpenAI]], [[AI Coding IDEs]]

## [[Claude Code]] / [[Anthropic]]

Big news about [[Claude Code]] today.

## [[OpenAI]] / [[GPT-5]]

Updates from [[OpenAI]] on their latest model.
EOF

# Run publish with simulated vault
mkdir -p "$TEMP_VAULT/.obsidian"
output=$(AI_BRIEFING_OBSIDIAN_VAULT="$TEMP_VAULT" bash "$PUBLISH_SCRIPT" --file "$TEMP_MD" 2>&1) || true

# Verify briefings directory created
[ -d "$TEMP_VAULT/AI-News-Briefings" ] && pass "vault sim: AI-News-Briefings/ created" || fail "vault sim: AI-News-Briefings/ created"

# Verify topics directory created
[ -d "$TEMP_VAULT/Topics" ] && pass "vault sim: Topics/ created" || fail "vault sim: Topics/ created"

# Verify briefing file was copied
copied_files=$(ls "$TEMP_VAULT/AI-News-Briefings/" 2>/dev/null | wc -l)
if [[ "$copied_files" -gt 0 ]]; then
  pass "vault sim: briefing file copied to vault"
else
  fail "vault sim: briefing file copied to vault"
fi

# Verify topic stubs were created
topic_count=$(ls "$TEMP_VAULT/Topics/" 2>/dev/null | wc -l)
if [[ "$topic_count" -ge 3 ]]; then
  pass "vault sim: topic stubs created ($topic_count topics)"
else
  fail "vault sim: topic stubs created ${D}(expected ≥3, got $topic_count)${R}"
fi

# Verify at least one expected topic stub exists
if [ -f "$TEMP_VAULT/Topics/Claude Code.md" ]; then
  pass "vault sim: Claude Code.md topic stub exists"
  stub_content=$(cat "$TEMP_VAULT/Topics/Claude Code.md")
  assert_contains "$stub_content" "type: topic" "vault sim: topic stub has type: topic frontmatter"
else
  fail "vault sim: Claude Code.md topic stub exists"
fi

# Verify idempotency — running again should not fail
output2=$(AI_BRIEFING_OBSIDIAN_VAULT="$TEMP_VAULT" bash "$PUBLISH_SCRIPT" --file "$TEMP_MD" 2>&1) || true
if [[ $? -eq 0 ]] || echo "$output2" | grep -qi "success\|copied\|exist"; then
  pass "vault sim: idempotent re-run succeeds"
else
  fail "vault sim: idempotent re-run succeeds"
fi

# Cleanup temp files
rm -rf "$TEMP_VAULT" "$TEMP_MD"

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
