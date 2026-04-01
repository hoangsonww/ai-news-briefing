#!/bin/bash
# Run all test suites. Non-blocking: no external services called.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -t 1 ]]; then
  B='\033[1m' D='\033[2m' R='\033[0m'
  GRN='\033[32m' RED='\033[31m' CYN='\033[36m' WHT='\033[37m'
else
  B='' D='' R='' GRN='' RED='' CYN='' WHT=''
fi

SUITES_PASS=0
SUITES_FAIL=0
TOTAL_FAIL=0

echo ""
echo -e "  ${D} _____                                                                 _____ ${R}"
echo -e "  ${D}( ___ )---------------------------------------------------------------( ___ )${R}"
echo -e "  ${D} |   |                                                                 |   | ${R}"
echo -e "  ${D} |   |${R}${B}${CYN}     _    ___   _   _                     ____       _       __  ${R}${D}|   | ${R}"
echo -e "  ${D} |   |${R}${B}${CYN}    / \\  |_ _| | \\ | | _____      _____  | __ ) _ __(_) ___ / _| ${R}${D}|   | ${R}"
echo -e "  ${D} |   |${R}${B}${CYN}   / _ \\  | |  |  \\| |/ _ \\ \\ /\\ / / __| |  _ \\| '__| |/ _ \\ |_  ${R}${D}|   | ${R}"
echo -e "  ${D} |   |${R}${B}${CYN}  / ___ \\ | |  | |\\  |  __/\\ V  V /\\__ \\ | |_) | |  | |  __/  _| ${R}${D}|   | ${R}"
echo -e "  ${D} |   |${R}${B}${CYN} /_/   \\_\\___| |_| \\_|\\___| \\_/\\_/ |___/ |____/|_|  |_|\\___|_|   ${R}${D}|   | ${R}"
echo -e "  ${D} |___|                                                                 |___| ${R}"
echo -e "  ${D}(_____)---------------------------------------------------------------(_____)${R}"
echo ""
echo -e "  ${D}Non-blocking test suite (no Claude, no webhooks, no Notion)${R}"
echo ""

for test_file in "$TESTS_DIR"/test-*.sh; do
  [ -f "$test_file" ] || continue

  if bash "$test_file"; then
    SUITES_PASS=$((SUITES_PASS + 1))
  else
    suite_failures=$?
    TOTAL_FAIL=$((TOTAL_FAIL + suite_failures))
    SUITES_FAIL=$((SUITES_FAIL + 1))
  fi
done

TOTAL_SUITES=$((SUITES_PASS + SUITES_FAIL))

echo ""
echo -e "  ${B}=====================================================${R}"
if [[ "$TOTAL_FAIL" -eq 0 ]]; then
  echo -e "  ${GRN}${B}  ALL $TOTAL_SUITES SUITES PASSED${R}"
else
  echo -e "  ${RED}${B}  $SUITES_FAIL of $TOTAL_SUITES suite(s) had failures${R}"
fi
echo -e "  ${B}=====================================================${R}"
echo ""

exit "$TOTAL_FAIL"
