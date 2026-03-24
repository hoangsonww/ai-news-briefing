#Requires -Version 5.1

param(
    [string]$BriefingDate = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogDir = Join-Path $ScriptDir "logs"
$Date = if ($BriefingDate) { $BriefingDate } else { Get-Date -Format "yyyy-MM-dd" }
$Time = Get-Date -Format "HH:mm:ss"
$LogFile = Join-Path $LogDir "$Date.log"
$Claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe"

# Ensure we can run even if Claude Code is open
$env:CLAUDECODE = $null

# Refresh webhook env vars from registry (parent shell may have stale values)
$regTeams = [Environment]::GetEnvironmentVariable("AI_BRIEFING_TEAMS_WEBHOOK", "User")
if ($regTeams) { $env:AI_BRIEFING_TEAMS_WEBHOOK = $regTeams }
$regSlack = [Environment]::GetEnvironmentVariable("AI_BRIEFING_SLACK_WEBHOOK", "User")
if ($regSlack) { $env:AI_BRIEFING_SLACK_WEBHOOK = $regSlack }

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    "$Date $ts $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

Write-Log "Starting AI News Briefing..."

$PromptFile = Join-Path $ScriptDir "prompt.md"
$Prompt = Get-Content -Path $PromptFile -Raw

# Inject date override if running for a non-today date
$today = Get-Date -Format "yyyy-MM-dd"
if ($Date -ne $today) {
    $datePrefix = @"
BRIEFING DATE OVERRIDE: $Date
Generate the briefing for $Date, NOT today ($today).
Search for AI news from $Date (past 24 hours relative to that date).
The Notion page title should use $Date.
The card.json filename should use $Date (logs/$Date-card.json).
---

"@
    $Prompt = $datePrefix + $Prompt
    Write-Log "Date override: generating briefing for $Date"
}

try {
    $output = & $Claude -p `
        --model opus `
        --dangerously-skip-permissions `
        $Prompt 2>&1

    $output | Out-File -FilePath $LogFile -Append -Encoding utf8
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Log "Briefing complete. Check Notion for today's report."

        # Post summary to Teams channel if webhook is configured
        $teamsScript = Join-Path $ScriptDir "scripts\notify-teams.ps1"
        $cardFile = Join-Path $LogDir "$Date-card.json"
        if ((Test-Path $teamsScript) -and $env:AI_BRIEFING_TEAMS_WEBHOOK) {
            Write-Log "Sending Teams notification..."
            try {
                & $teamsScript -All -CardFile $cardFile
                Write-Log "Teams notification sent."
            } catch {
                Write-Log "Teams notification failed: $_"
            }
        }

        # Post summary to Slack channel if webhook is configured
        $slackScript = Join-Path $ScriptDir "scripts\notify-slack.ps1"
        if ((Test-Path $slackScript) -and $env:AI_BRIEFING_SLACK_WEBHOOK) {
            Write-Log "Sending Slack notification..."
            try {
                & $slackScript -All -CardFile $cardFile
                Write-Log "Slack notification sent."
            } catch {
                Write-Log "Slack notification failed: $_"
            }
        }
    } else {
        Write-Log "Briefing FAILED with exit code $exitCode."
    }
} catch {
    Write-Log "Briefing FAILED with error: $_"
}

# Clean up logs older than 30 days
Get-ChildItem -Path $LogDir -Filter "*.log" -File |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Force -ErrorAction SilentlyContinue
