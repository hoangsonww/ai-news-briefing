#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# test-notion.ps1 — Test Notion MCP connectivity on Windows.
# Verifies that Claude Code can reach the Notion workspace and the target database.
# Usage: .\scripts\test-notion.ps1

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe"

if (-not (Test-Path $Claude)) {
    Write-Host "Claude CLI not found at $Claude"
    exit 1
}

$env:CLAUDECODE = $null

Write-Host ""
Write-Host "  AI News Briefing - Notion Connectivity Test" -ForegroundColor White
Write-Host "  ============================================="
Write-Host ""
Write-Host "  Testing Notion MCP connection via Claude Code..."
Write-Host ""

$prompt = @"
Test the Notion MCP connection. Do these two things:
1. Use mcp__notion__notion-search to search for 'AI Daily Briefing'. Report how many results you find.
2. Report whether the Notion MCP tools are available and responding.

Be brief. Just report: connected or not, how many pages found, and any errors.
"@

try {
    $output = & $Claude -p `
        --model haiku `
        --dangerously-skip-permissions `
        --max-budget-usd 0.10 `
        $prompt 2>&1

    $output | Write-Host
    $exitCode = $LASTEXITCODE

    Write-Host ""
    if ($exitCode -eq 0) {
        Write-Host "  Test complete." -ForegroundColor Green
    } else {
        Write-Host "  Test failed with exit code $exitCode." -ForegroundColor Red
        Write-Host "  Check that the Notion MCP is configured in Claude Code's MCP settings."
    }
} catch {
    Write-Host "  Test failed with error: $_" -ForegroundColor Red
}
Write-Host ""
