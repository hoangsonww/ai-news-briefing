#Requires -Version 5.1
<#
.SYNOPSIS
    Non-blocking test suite for AI News Briefing (Windows).
    Tests script structure, arg handling, template substitution,
    card JSON, and notification pipeline -- no external services called.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)

$Pass = 0
$Fail = 0

function Test-Pass { param([string]$Name); $script:Pass++; Write-Host "  PASS  $Name" -ForegroundColor Green }
function Test-Fail { param([string]$Name); $script:Fail++; Write-Host "  FAIL  $Name" -ForegroundColor Red }
function Assert-True { param([bool]$Cond, [string]$Name); if ($Cond) { Test-Pass $Name } else { Test-Fail $Name } }
function Assert-Contains { param([string]$Text, [string]$Pattern, [string]$Name)
    if ($Text -match [regex]::Escape($Pattern)) { Test-Pass $Name } else { Test-Fail "$Name (missing '$Pattern')" }
}

Write-Host ""
Write-Host "   _____                                                                 _____ " -ForegroundColor DarkGray
Write-Host "  ( ___ )---------------------------------------------------------------( ___ )" -ForegroundColor DarkGray
Write-Host "   |   |                                                                 |   | " -ForegroundColor DarkGray
Write-Host "   |   |" -ForegroundColor DarkGray -NoNewline
Write-Host "     _    ___   _   _                     ____       _       __  " -ForegroundColor Cyan -NoNewline
Write-Host "|   | " -ForegroundColor DarkGray
Write-Host "   |   |" -ForegroundColor DarkGray -NoNewline
Write-Host "    / \  |_ _| | \ | | _____      _____  | __ ) _ __(_) ___ / _| " -ForegroundColor Cyan -NoNewline
Write-Host "|   | " -ForegroundColor DarkGray
Write-Host "   |   |" -ForegroundColor DarkGray -NoNewline
Write-Host "   / _ \  | |  |  \| |/ _ \ \ /\ / / __| |  _ \| '__| |/ _ \ |_  " -ForegroundColor Cyan -NoNewline
Write-Host "|   | " -ForegroundColor DarkGray
Write-Host "   |   |" -ForegroundColor DarkGray -NoNewline
Write-Host "  / ___ \ | |  | |\  |  __/\ V  V /\__ \ | |_) | |  | |  __/  _| " -ForegroundColor Cyan -NoNewline
Write-Host "|   | " -ForegroundColor DarkGray
Write-Host "   |   |" -ForegroundColor DarkGray -NoNewline
Write-Host " /_/   \_\___| |_| \_|\___| \_/\_/ |___/ |____/|_|  |_|\___|_|   " -ForegroundColor Cyan -NoNewline
Write-Host "|   | " -ForegroundColor DarkGray
Write-Host "   |___|                                                                 |___| " -ForegroundColor DarkGray
Write-Host "  (_____)---------------------------------------------------------------(_____)  " -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Non-blocking PowerShell test suite" -ForegroundColor DarkGray

# =====================================================================
#  1. FILE EXISTENCE
# =====================================================================
Write-Host ""
Write-Host "=== File existence ===" -ForegroundColor Cyan

$requiredFiles = @(
    "briefing.ps1", "briefing.sh", "prompt.md",
    "custom-brief.ps1", "custom-brief.sh", "prompt-custom-brief.md",
    "commands\ai-news-briefing.md", "commands\custom-brief.md",
    "install-task.ps1",
    "scripts\notify-teams.ps1", "scripts\notify-teams.sh",
    "scripts\notify-slack.ps1", "scripts\notify-slack.sh",
    "scripts\teams-to-slack.py"
)

foreach ($f in $requiredFiles) {
    $path = Join-Path $ScriptDir $f
    Assert-True (Test-Path $path) "$f exists"
}

# =====================================================================
#  2. POWERSHELL SYNTAX (parse without executing)
# =====================================================================
Write-Host ""
Write-Host "=== PowerShell syntax ===" -ForegroundColor Cyan

$ps1Files = @("briefing.ps1", "custom-brief.ps1", "install-task.ps1",
              "scripts\notify-teams.ps1", "scripts\notify-slack.ps1")

foreach ($f in $ps1Files) {
    $path = Join-Path $ScriptDir $f
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
    Assert-True ($errors.Count -eq 0) "$f valid PowerShell syntax"
}

# =====================================================================
#  3. DAILY BRIEFING PROMPT
# =====================================================================
Write-Host ""
Write-Host "=== Daily briefing prompt (prompt.md) ===" -ForegroundColor Cyan

$prompt = Get-Content (Join-Path $ScriptDir "prompt.md") -Raw
Assert-Contains $prompt "Step 0" "prompt: Step 0 (covered stories)"
Assert-Contains $prompt "Step 1" "prompt: Step 1 (search)"
Assert-Contains $prompt "Step 2" "prompt: Step 2 (compile)"
Assert-Contains $prompt "Step 3" "prompt: Step 3 (write to Notion)"
Assert-Contains $prompt "Step 4" "prompt: Step 4 (card JSON)"
Assert-Contains $prompt "Step 5" "prompt: Step 5 (update covered stories)"
Assert-Contains $prompt "856794cc-d871-4a95-be2d-2a1600920a19" "prompt: data_source_id"
Assert-Contains $prompt "covered-stories.txt" "prompt: dedup file"
Assert-Contains $prompt "Claude Code" "prompt: covers Claude Code topic"
Assert-Contains $prompt "OpenAI" "prompt: covers OpenAI topic"
Assert-Contains $prompt "Open Source AI" "prompt: covers Open Source AI"

# =====================================================================
#  4. CUSTOM BRIEF PROMPT
# =====================================================================
Write-Host ""
Write-Host "=== Custom brief prompt (prompt-custom-brief.md) ===" -ForegroundColor Cyan

$cbPrompt = Get-Content (Join-Path $ScriptDir "prompt-custom-brief.md") -Raw
Assert-Contains $cbPrompt "{{TOPIC}}" "cb prompt: {{TOPIC}} placeholder"
Assert-Contains $cbPrompt "{{DATE}}" "cb prompt: {{DATE}} placeholder"
Assert-Contains $cbPrompt "{{TIMESTAMP}}" "cb prompt: {{TIMESTAMP}} placeholder"
Assert-Contains $cbPrompt "{{PUBLISH_NOTION}}" "cb prompt: {{PUBLISH_NOTION}} placeholder"
Assert-Contains $cbPrompt "{{PUBLISH_TEAMS_SLACK}}" "cb prompt: {{PUBLISH_TEAMS_SLACK}} placeholder"
Assert-Contains $cbPrompt "Phase 1" "cb prompt: Phase 1 (Broad Discovery)"
Assert-Contains $cbPrompt "Phase 2" "cb prompt: Phase 2 (Deep Dive)"
Assert-Contains $cbPrompt "Phase 3" "cb prompt: Phase 3 (Compile)"
Assert-Contains $cbPrompt "Agent 1" "cb prompt: defines Agent 1"
Assert-Contains $cbPrompt "Agent 5" "cb prompt: defines Agent 5"
Assert-Contains $cbPrompt "clickable source link" "cb prompt: requires citations"
Assert-Contains $cbPrompt "Adaptive Card" "cb prompt: card template"

# =====================================================================
#  5. TEMPLATE SUBSTITUTION ([string]::Replace)
# =====================================================================
Write-Host ""
Write-Host "=== Template substitution ===" -ForegroundColor Cyan

$testTopic = 'AI in R&D for $100B markets (2026)'
$testDate = "2026-04-01"
$testTs = "2026-04-01-090000"

$result = $cbPrompt.
    Replace('{{TOPIC}}', $testTopic).
    Replace('{{DATE}}', $testDate).
    Replace('{{TIMESTAMP}}', $testTs).
    Replace('{{PUBLISH_NOTION}}', 'true').
    Replace('{{PUBLISH_OBSIDIAN}}', 'false').
    Replace('{{PUBLISH_TEAMS_SLACK}}', 'false')

Assert-Contains $result 'AI in R&D' "substitution: handles & in topic"
Assert-Contains $result '$100B' "substitution: handles dollar sign in topic"
Assert-Contains $result '(2026)' "substitution: handles parens in topic"
Assert-Contains $result '2026-04-01' "substitution: replaces {{DATE}}"

$leftover = ([regex]::Matches($result, '\{\{[A-Z_]+\}\}')).Count
Assert-True ($leftover -eq 0) "substitution: no leftover {{}} placeholders ($leftover found)"

# =====================================================================
#  6. CUSTOM-BRIEF.PS1 STRUCTURE
# =====================================================================
Write-Host ""
Write-Host "=== custom-brief.ps1 structure ===" -ForegroundColor Cyan

$cbScript = Get-Content (Join-Path $ScriptDir "custom-brief.ps1") -Raw
Assert-Contains $cbScript "param(" "cb ps1: has param block"
Assert-Contains $cbScript '[string]$Topic' "cb ps1: -Topic parameter"
Assert-Contains $cbScript '[switch]$Notion' "cb ps1: -Notion switch"
Assert-Contains $cbScript '[switch]$Teams' "cb ps1: -Teams switch"
Assert-Contains $cbScript '[switch]$Slack' "cb ps1: -Slack switch"
Assert-Contains $cbScript "Read-Host" "cb ps1: interactive REPL"
Assert-Contains $cbScript "Replace(" "cb ps1: uses literal Replace (not -replace regex)"
Assert-Contains $cbScript "notify-teams.ps1" "cb ps1: calls Teams notifier"
Assert-Contains $cbScript "notify-slack.ps1" "cb ps1: calls Slack notifier"
Assert-Contains $cbScript "CLAUDECODE" "cb ps1: clears CLAUDECODE env"

# =====================================================================
#  7. CARD JSON VALIDATION
# =====================================================================
Write-Host ""
Write-Host "=== Card JSON validation ===" -ForegroundColor Cyan

$cardDir = Join-Path $ScriptDir "logs"
$cards = @(Get-ChildItem -Path $cardDir -Filter "*-card.json" -ErrorAction SilentlyContinue)

if ($cards.Count -gt 0) {
    Test-Pass "found $($cards.Count) card JSON files"
    $invalidCount = 0
    foreach ($card in $cards) {
        try {
            $null = Get-Content $card.FullName -Raw | ConvertFrom-Json
        } catch {
            $invalidCount++
            Test-Fail "$($card.Name): invalid JSON"
        }
    }
    if ($invalidCount -eq 0) { Test-Pass "all $($cards.Count) cards are valid JSON" }

    # Structure check on latest card
    $latest = $cards | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $cardJson = Get-Content $latest.FullName -Raw
    Assert-Contains $cardJson '"type": "message"' "latest card: message envelope"
    Assert-Contains $cardJson '"type": "AdaptiveCard"' "latest card: AdaptiveCard type"
    Assert-Contains $cardJson '"version": "1.4"' "latest card: v1.4"
    Assert-Contains $cardJson '"Action.OpenUrl"' "latest card: action button"
    Assert-Contains $cardJson "notion.so" "latest card: Notion link"
    Assert-Contains $cardJson "Sources" "latest card: Sources section"

    $size = (Get-Item $latest.FullName).Length
    Assert-True ($size -lt 28000) "latest card: size ${size}B under 28KB limit"
} else {
    Test-Pass "no card files yet (OK for fresh install)"
}

# =====================================================================
#  8. TEAMS-TO-SLACK CONVERTER
# =====================================================================
Write-Host ""
Write-Host "=== Teams-to-Slack converter ===" -ForegroundColor Cyan

if ($cards.Count -gt 0) {
    $latest = $cards | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $converter = Join-Path $ScriptDir "scripts\teams-to-slack.py"
    # Write converter output to temp file, then validate with python
    $tmpSlack = [System.IO.Path]::GetTempFileName()
    & python3 $converter $latest.FullName $tmpSlack 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Test-Pass "converter: processes latest card (exit 0)"
        # Validate JSON via python (more reliable than PS5.1 ConvertFrom-Json for large payloads)
        & python3 -m json.tool $tmpSlack | Out-Null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Test-Pass "converter: output is valid JSON"
        } else {
            Test-Fail "converter: output is not valid JSON"
        }
        $slackStr = Get-Content $tmpSlack -Raw
        Remove-Item $tmpSlack -Force -ErrorAction SilentlyContinue
        Assert-Contains $slackStr '"type": "header"' "converter: Slack header block"
        Assert-Contains $slackStr '"type": "divider"' "converter: Slack divider"
        Assert-Contains $slackStr '"type": "section"' "converter: Slack sections"
        Assert-Contains $slackStr "Open Full Briefing in Notion" "converter: Notion button"
    } else {
        Test-Fail "converter: failed (exit $LASTEXITCODE)"
    }
} else {
    Test-Pass "no card to test converter (OK for fresh install)"
}

# =====================================================================
#  9. NOTIFICATION SCRIPT STRUCTURE
# =====================================================================
Write-Host ""
Write-Host "=== Notification script structure ===" -ForegroundColor Cyan

$teamsPs = Get-Content (Join-Path $ScriptDir "scripts\notify-teams.ps1") -Raw
Assert-Contains $teamsPs "AI_BRIEFING_TEAMS_WEBHOOK" "notify-teams.ps1: reads webhook env var"
Assert-Contains $teamsPs "ConvertFrom-Json" "notify-teams.ps1: validates JSON"
Assert-Contains $teamsPs "Invoke-WebRequest" "notify-teams.ps1: uses Invoke-WebRequest"
Assert-Contains $teamsPs "-All" "notify-teams.ps1: supports -All flag"

$slackPs = Get-Content (Join-Path $ScriptDir "scripts\notify-slack.ps1") -Raw
Assert-Contains $slackPs "AI_BRIEFING_SLACK_WEBHOOK" "notify-slack.ps1: reads webhook env var"
Assert-Contains $slackPs "teams-to-slack.py" "notify-slack.ps1: calls converter"

# =====================================================================
#  10. DOCUMENTATION
# =====================================================================
Write-Host ""
Write-Host "=== Documentation ===" -ForegroundColor Cyan

$docs = @("README.md", "ARCHITECTURE.md", "CUSTOM_BRIEF.md", "SETUP.md",
          "E2E_FLOW.md", "NOTIFY_TEAMS.md", "NOTIFY_SLACK.md")
foreach ($d in $docs) {
    $path = Join-Path $ScriptDir $d
    Assert-True (Test-Path $path) "$d exists"
}

$readme = Get-Content (Join-Path $ScriptDir "README.md") -Raw
Assert-Contains $readme "Custom Brief" "README: mentions Custom Brief feature"
Assert-Contains $readme "custom-brief.sh" "README: references bash script"
Assert-Contains $readme "custom-brief.ps1" "README: references PowerShell script"

$cbDoc = Get-Content (Join-Path $ScriptDir "CUSTOM_BRIEF.md") -Raw
Assert-Contains $cbDoc "mermaid" "CUSTOM_BRIEF.md: has Mermaid diagrams"
Assert-Contains $cbDoc "--topic" "CUSTOM_BRIEF.md: documents --topic flag"
Assert-Contains $cbDoc "--notion" "CUSTOM_BRIEF.md: documents --notion flag"

# =====================================================================
#  SUMMARY
# =====================================================================
Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
if ($Fail -eq 0) {
    Write-Host "  ALL TESTS PASSED: $Pass passed, 0 failed" -ForegroundColor Green
} else {
    Write-Host "  RESULTS: $Pass passed, $Fail failed" -ForegroundColor Red
}
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""

exit $Fail
