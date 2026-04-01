#!/bin/bash
# Cross-platform portability tests — verifies scripts work on macOS/Linux/Git Bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0

if [[ -t 1 ]]; then
  B='\033[1m' D='\033[2m' R='\033[0m'
  GRN='\033[32m' RED='\033[31m' CYN='\033[36m' MAG='\033[35m'
else
  B='' D='' R='' GRN='' RED='' CYN='' MAG=''
fi

pass() { PASS=$((PASS + 1)); echo -e "  ${GRN}PASS${R}  $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "  ${RED}FAIL${R}  $1"; }
section() { echo ""; echo -e "  ${CYN}${B}$1${R}"; }

echo ""
echo -e "  ${MAG}${B}================================================${R}"
echo -e "  ${MAG}${B}  portability tests${R}"
echo -e "  ${MAG}${B}================================================${R}"

# -- Bash version ------------------------------------------
section "Bash version"
bash_ver="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
if [[ "${BASH_VERSINFO[0]}" -ge 3 ]]; then
  pass "bash $bash_ver (>= 3.0 required for PIPESTATUS, here-strings)"
else
  fail "bash $bash_ver (need >= 3.0)"
fi

# -- Platform detection ------------------------------------
section "Platform"
platform="$(uname -s)"
pass "running on $platform"

# -- Required commands -------------------------------------
section "Required commands"
for cmd in awk date tee cat grep mkdir; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd available"
  else
    fail "$cmd not found"
  fi
done

# Python (needed for Slack converter and JSON validation)
if command -v python3 >/dev/null 2>&1; then
  pyver=$(python3 --version 2>&1)
  pass "python3 available ($pyver)"
else
  fail "python3 not found (needed for Slack conversion)"
fi

# curl (needed for webhook delivery)
if command -v curl >/dev/null 2>&1; then
  pass "curl available"
else
  fail "curl not found (needed for webhook POST)"
fi

# -- Shebang lines ----------------------------------------
section "Shebang lines"
for f in custom-brief.sh briefing.sh scripts/notify-teams.sh scripts/notify-slack.sh; do
  path="$SCRIPT_DIR/$f"
  if [[ -f "$path" ]]; then
    shebang=$(head -1 "$path")
    if [[ "$shebang" == "#!/bin/bash" ]]; then
      pass "$f: #!/bin/bash"
    elif [[ "$shebang" == "#!/usr/bin/env bash" ]]; then
      pass "$f: #!/usr/bin/env bash"
    else
      fail "$f: unexpected shebang '$shebang'"
    fi
  fi
done

# -- No bashisms beyond bash 3.2 (macOS minimum) ----------
section "Bash 3.2 compatibility (macOS)"
for f in custom-brief.sh briefing.sh; do
  path="$SCRIPT_DIR/$f"
  # Check for bash 4+ features that would break on macOS
  # - associative arrays (declare -A)
  # - &>> (append redirect both)
  # - |& (pipe stderr)
  # - ${var,,} / ${var^^} (case modification)
  if grep -qE 'declare -A|&>>|\|&|\$\{[a-zA-Z_]+,,\}|\$\{[a-zA-Z_]+\^\^\}' "$path" 2>/dev/null; then
    fail "$f: uses bash 4+ features (breaks on macOS bash 3.2)"
  else
    pass "$f: no bash 4+ features"
  fi
done

# -- POSIX awk compatibility (BSD awk on macOS) ------------
section "awk compatibility"
# Test that gsub with -v works on this platform's awk
result=$(awk -v val="hello world" 'BEGIN { str="test {{X}} end"; gsub(/\{\{X\}\}/, val, str); print str }')
if [[ "$result" == "test hello world end" ]]; then
  pass "awk gsub with -v substitution works"
else
  fail "awk gsub with -v substitution failed (got: $result)"
fi

# Test multi-line input via here-string
line_count=$(awk '{print}' <<< "line1
line2
line3" | wc -l | tr -d ' ')
if [[ "$line_count" -eq 3 ]]; then
  pass "awk with here-string handles multi-line input"
else
  fail "awk here-string: expected 3 lines, got $line_count"
fi

# -- date format compatibility -----------------------------
section "date format"
d=$(date +%Y-%m-%d)
if [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  pass "date +%Y-%m-%d produces $d"
else
  fail "date +%Y-%m-%d produced unexpected: $d"
fi

ts=$(date +%Y-%m-%d-%H%M%S)
if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$ ]]; then
  pass "date +%Y-%m-%d-%H%M%S produces $ts"
else
  fail "date timestamp produced unexpected: $ts"
fi

# -- echo -e support ---------------------------------------
section "echo -e support"
result=$(echo -e "a\tb")
if [[ "$result" == *$'\t'* ]]; then
  pass "echo -e interprets escape sequences"
else
  fail "echo -e does not interpret escapes (would break colored output)"
fi

# -- Notify scripts use -f not -x (no execute bit needed) --
section "Notify script invocation"
# custom-brief.sh should use -f (file exists) not -x (executable)
# so notifications work on fresh clones where scripts lack +x
cb=$(cat "$SCRIPT_DIR/custom-brief.sh")
if echo "$cb" | grep -q '\-f "$TEAMS_SCRIPT"'; then
  pass "custom-brief.sh: uses -f for Teams script check (not -x)"
else
  fail "custom-brief.sh: uses -x for Teams script check (breaks without chmod)"
fi
if echo "$cb" | grep -q '\-f "$SLACK_SCRIPT"'; then
  pass "custom-brief.sh: uses -f for Slack script check (not -x)"
else
  fail "custom-brief.sh: uses -x for Slack script check (breaks without chmod)"
fi
# Verify it calls via 'bash' explicitly
if echo "$cb" | grep -q 'bash "$TEAMS_SCRIPT"'; then
  pass "custom-brief.sh: calls Teams script via 'bash' (no +x needed)"
else
  fail "custom-brief.sh: calls Teams script directly (needs +x)"
fi
if echo "$cb" | grep -q 'bash "$SLACK_SCRIPT"'; then
  pass "custom-brief.sh: calls Slack script via 'bash' (no +x needed)"
else
  fail "custom-brief.sh: calls Slack script directly (needs +x)"
fi

# -- ANSI color auto-disable when piped --------------------
section "Color safety"
# When piped, colors should be disabled (no raw escape codes in output)
piped_output=$(bash "$SCRIPT_DIR/custom-brief.sh" --help 2>&1 | cat)
if echo "$piped_output" | grep -qP '\033\['; then
  fail "help output contains raw ANSI escapes when piped"
else
  pass "help output is clean when piped (no ANSI escapes)"
fi

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
