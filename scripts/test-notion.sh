#!/bin/bash
set -euo pipefail

# test-notion.sh — Test Notion MCP connectivity by searching for existing briefings.
# Verifies that Claude Code can reach the Notion workspace and the target database.
# Usage: ./scripts/test-notion.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE="${HOME}/.local/bin/claude"

if [ ! -f "$CLAUDE" ]; then
    echo "Claude CLI not found at $CLAUDE"
    exit 1
fi

# Ensure we can run outside Claude Code
unset CLAUDECODE 2>/dev/null || true

echo ""
echo "  AI News Briefing — Notion Connectivity Test"
echo "  ============================================="
echo ""
echo "  Testing Notion MCP connection via Claude Code..."
echo ""

"$CLAUDE" -p \
    --model haiku \
    --dangerously-skip-permissions \
    "Test the Notion MCP connection. Do these two things:
1. Use mcp__notion__notion-search to search for 'AI Daily Briefing'. Report how many results you find.
2. Report whether the Notion MCP tools are available and responding.

Be brief. Just report: connected or not, how many pages found, and any errors." 2>&1

EXIT_CODE=$?
echo ""

if [ "$EXIT_CODE" -eq 0 ]; then
    echo "  Test complete."
else
    echo "  Test failed with exit code $EXIT_CODE."
    echo "  Check that the Notion MCP is configured in Claude Code's MCP settings."
fi
echo ""
