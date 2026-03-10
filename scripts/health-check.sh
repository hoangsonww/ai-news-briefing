#!/bin/bash
set -euo pipefail

# health-check.sh — Verify the entire AI News Briefing setup is correct.
# Checks: Claude CLI, prompt structure, scheduler, logs directory, Notion config.

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE="${HOME}/.local/bin/claude"
PASS=0
FAIL=0
WARN=0

green()  { printf "\033[32m%s\033[0m" "$1"; }
red()    { printf "\033[31m%s\033[0m" "$1"; }
yellow() { printf "\033[33m%s\033[0m" "$1"; }
dim()    { printf "\033[90m%s\033[0m" "$1"; }

check_pass() { PASS=$((PASS + 1)); printf "  %-40s %s\n" "$1" "$(green "OK")"; }
check_fail() { FAIL=$((FAIL + 1)); printf "  %-40s %s\n" "$1" "$(red "FAIL: $2")"; }
check_warn() { WARN=$((WARN + 1)); printf "  %-40s %s\n" "$1" "$(yellow "WARN: $2")"; }

echo ""
echo "  AI News Briefing — Health Check"
echo "  ================================"
echo ""

# --- Claude CLI ---
echo "  $(dim '[Claude CLI]')"
if [ -f "$CLAUDE" ]; then
    check_pass "Claude binary exists"
    if "$CLAUDE" --version >/dev/null 2>&1; then
        VERSION=$("$CLAUDE" --version 2>&1 | head -1)
        check_pass "Claude responds ($VERSION)"
    else
        check_fail "Claude responds" "binary found but --version failed"
    fi
else
    check_fail "Claude binary exists" "not found at $CLAUDE"
    check_fail "Claude responds" "binary missing"
fi
echo ""

# --- Project Files ---
echo "  $(dim '[Project Files]')"
for f in prompt.md briefing.sh briefing.ps1 com.ainews.briefing.plist install-task.ps1 Makefile; do
    if [ -f "$SCRIPT_DIR/$f" ]; then
        check_pass "$f"
    else
        check_fail "$f" "missing"
    fi
done
echo ""

# --- Prompt Structure ---
echo "  $(dim '[Prompt Structure]')"
for section in "Step 0" "Step 1" "Step 2" "Step 3" "Topics to Search" "Date Attribution" "Notion Formatting"; do
    if grep -q "$section" "$SCRIPT_DIR/prompt.md" 2>/dev/null; then
        check_pass "prompt.md contains '$section'"
    else
        check_warn "prompt.md contains '$section'" "section not found"
    fi
done

TOPIC_COUNT=$(grep -c '^\d\.' "$SCRIPT_DIR/prompt.md" 2>/dev/null || echo "0")
if [ "$TOPIC_COUNT" -ge 9 ]; then
    check_pass "Topic count ($TOPIC_COUNT topics)"
else
    check_warn "Topic count ($TOPIC_COUNT topics)" "expected 9+"
fi

if grep -q "data_source_id" "$SCRIPT_DIR/prompt.md" 2>/dev/null; then
    check_pass "Notion data_source_id present"
else
    check_fail "Notion data_source_id present" "missing from prompt.md"
fi
echo ""

# --- Logs Directory ---
echo "  $(dim '[Logs]')"
LOG_DIR="$SCRIPT_DIR/logs"
if [ -d "$LOG_DIR" ]; then
    check_pass "logs/ directory exists"
    LOG_COUNT=$(find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$LOG_COUNT" -gt 0 ]; then
        LATEST=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
        check_pass "$LOG_COUNT log file(s), latest: $(basename "$LATEST")"
    else
        check_warn "Log files" "directory exists but no logs yet"
    fi
else
    check_warn "logs/ directory exists" "will be created on first run"
fi
echo ""

# --- Scheduler (macOS) ---
if [ "$(uname -s)" = "Darwin" ]; then
    echo "  $(dim '[macOS Scheduler]')"
    if launchctl list 2>/dev/null | grep -q "ainews"; then
        check_pass "launchd agent loaded"
    else
        check_warn "launchd agent loaded" "not loaded — run: make install"
    fi

    PLIST="$HOME/Library/LaunchAgents/com.ainews.briefing.plist"
    if [ -f "$PLIST" ]; then
        check_pass "plist installed at ~/Library/LaunchAgents/"
    else
        check_warn "plist installed" "not found — run: make install"
    fi
    echo ""
fi

# --- Script Permissions ---
echo "  $(dim '[Permissions]')"
if [ -x "$SCRIPT_DIR/briefing.sh" ]; then
    check_pass "briefing.sh is executable"
else
    check_warn "briefing.sh is executable" "run: chmod +x briefing.sh"
fi
echo ""

# --- Summary ---
TOTAL=$((PASS + FAIL + WARN))
echo "  --------------------------------"
printf "  Total: %d checks — " "$TOTAL"
printf "%s passed" "$(green "$PASS")"
if [ "$WARN" -gt 0 ]; then printf ", %s warnings" "$(yellow "$WARN")"; fi
if [ "$FAIL" -gt 0 ]; then printf ", %s failed" "$(red "$FAIL")"; fi
echo ""
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
