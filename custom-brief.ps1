#Requires -Version 5.1

<#
.SYNOPSIS
    Deep-research a topic and produce a comprehensive news briefing.
.DESCRIPTION
    Uses Claude Code in headless mode to conduct multi-agent deep research on a
    user-defined topic, then optionally publishes to Notion, Teams, and/or Slack.
    The full briefing is always printed to the terminal.
.PARAMETER Topic
    The topic to research. If omitted, enters interactive mode.
.PARAMETER Notion
    Publish the briefing to Notion.
.PARAMETER Teams
    Send a summary card to Microsoft Teams.
.PARAMETER Slack
    Send a summary card to Slack.
.EXAMPLE
    .\custom-brief.ps1 -Topic "AI in healthcare" -Notion -Teams
.EXAMPLE
    .\custom-brief.ps1 -Topic "quantum computing" -Notion
.EXAMPLE
    .\custom-brief.ps1   # interactive mode
#>

param(
    [string]$Topic = "",
    [switch]$Notion,
    [switch]$Teams,
    [switch]$Slack
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogDir = Join-Path $ScriptDir "logs"
$Date = Get-Date -Format "yyyy-MM-dd"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

# Resolve Claude CLI path
$Claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
if (-not (Test-Path $Claude)) {
    $inPath = Get-Command "claude" -ErrorAction SilentlyContinue
    if ($inPath) {
        $Claude = $inPath.Source
    } else {
        Write-Error "Claude CLI not found. Install it at $env:USERPROFILE\.local\bin\claude.exe"
        exit 1
    }
}

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

# -- Banner ------------------------------------------------
function Write-Banner {
    $d = "DarkGray"
    $c = "Cyan"
    Write-Host ""
    Write-Host "   _____                                                                 _____ " -ForegroundColor $d
    Write-Host "  ( ___ )---------------------------------------------------------------( ___ )" -ForegroundColor $d
    Write-Host "   |   |                                                                 |   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host "     _    ___   _   _                     ____       _       __  " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host "    / \  |_ _| | \ | | _____      _____  | __ ) _ __(_) ___ / _| " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host "   / _ \  | |  |  \| |/ _ \ \ /\ / / __| |  _ \| '__| |/ _ \ |_  " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host "  / ___ \ | |  | |\  |  __/\ V  V /\__ \ | |_) | |  | |  __/  _| " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host " /_/   \_\___| |_| \_|\___| \_/\_/ |___/ |____/|_|  |_|\___|_|   " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |___|                                                                 |___| " -ForegroundColor $d
    Write-Host "  (_____)---------------------------------------------------------------(_____)  " -ForegroundColor $d
}

# -- Interactive REPL (if no topic provided) ---------------
if (-not $Topic) {
    Write-Banner
    Write-Host ""
    Write-Host "  Interactive Mode" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Topic: " -NoNewline
    $Topic = Read-Host
    if (-not $Topic) {
        Write-Host "  Error: topic cannot be empty." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "  Publish to:" -ForegroundColor DarkGray
    $yn = Read-Host "    Notion? [y/N]"
    if ($yn -match "^[Yy]") { $Notion = [switch]::new($true) }
    $yn = Read-Host "    Teams?  [y/N]"
    if ($yn -match "^[Yy]") { $Teams = [switch]::new($true) }
    $yn = Read-Host "    Slack?  [y/N]"
    if ($yn -match "^[Yy]") { $Slack = [switch]::new($true) }
    Write-Host ""
}

# -- Derive flags ------------------------------------------
$PublishNotion = if ($Notion) { "true" } else { "false" }
$PublishTeamsSlack = if ($Teams -or $Slack) { "true" } else { "false" }

$LogFile = Join-Path $LogDir "custom-$Timestamp.log"
$CardFile = Join-Path $LogDir "custom-$Timestamp-card.json"

# -- Build the prompt --------------------------------------
$PromptTemplate = Get-Content -Path (Join-Path $ScriptDir "prompt-custom-brief.md") -Raw

# Use [string]::Replace() for literal substitution -- avoids regex
# backreference issues when topic contains $1, $0, etc.
$Prompt = $PromptTemplate.
    Replace('{{TOPIC}}', $Topic).
    Replace('{{DATE}}', $Date).
    Replace('{{TIMESTAMP}}', $Timestamp).
    Replace('{{PUBLISH_NOTION}}', $PublishNotion).
    Replace('{{PUBLISH_TEAMS_SLACK}}', $PublishTeamsSlack)

# -- Derive Teams/Slack booleans for display ---------------
$PublishTeams = if ($Teams) { "true" } else { "false" }
$PublishSlack = if ($Slack) { "true" } else { "false" }

# -- Styled boolean label ---------------------------------
function Write-Flag {
    param([string]$Label, [string]$Value)
    Write-Host "  $Label" -NoNewline
    # Pad to align
    Write-Host (" " * (10 - $Label.Length)) -NoNewline
    if ($Value -eq "true") {
        Write-Host "yes" -ForegroundColor Green
    } else {
        Write-Host "no" -ForegroundColor DarkGray
    }
}

# -- Print run summary ------------------------------------
Write-Banner
Write-Host ""
Write-Host "  Deep Research" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Topic     " -NoNewline
Write-Host "$Topic"
Write-Flag "Notion" $PublishNotion
Write-Flag "Teams" $PublishTeams
Write-Flag "Slack" $PublishSlack
Write-Host "  Log       " -NoNewline -ForegroundColor DarkGray
Write-Host "$LogFile" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Launching 5 parallel research agents..." -ForegroundColor Magenta
Write-Host "  This may take a few minutes." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""

# -- Log header --------------------------------------------
function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    "$Date $ts $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

Write-Log "Custom Brief -- Topic: $Topic"
Write-Log "Notion=$PublishNotion Teams=$PublishTeams Slack=$PublishSlack"

# -- Run Claude --------------------------------------------
try {
    # Stream Claude output line-by-line to both console and log in real time.
    # Do NOT buffer into a variable -- that hides the briefing until Claude finishes.
    & $Claude -p `
        --model opus `
        --dangerously-skip-permissions `
        $Prompt 2>&1 | ForEach-Object {
            Write-Host $_
            $_ | Out-File -FilePath $LogFile -Append -Encoding utf8
        }

    $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 }

    if ($exitCode -ne 0) {
        Write-Log "Custom brief FAILED with exit code $exitCode."
        Write-Host ""
        Write-Host "  FAILED" -ForegroundColor Red -NoNewline
        Write-Host "  Custom brief failed (exit code $exitCode)" -ForegroundColor Red
        Write-Host "  Log: $LogFile" -ForegroundColor DarkGray
        exit $exitCode
    }

    Write-Log "Custom brief complete."

    # -- Post-processing: Teams notification ---------------
    if ($Teams) {
        $teamsScript = Join-Path $ScriptDir "scripts\notify-teams.ps1"
        if ((Test-Path $teamsScript) -and $env:AI_BRIEFING_TEAMS_WEBHOOK) {
            if (Test-Path $CardFile) {
                Write-Host ""
                Write-Host "  Sending to Teams..." -ForegroundColor DarkGray
                Write-Log "Sending Teams notification..."
                try {
                    & $teamsScript -All -CardFile $CardFile
                    Write-Log "Teams notification sent."
                    Write-Host "  Teams     " -ForegroundColor Green -NoNewline
                    Write-Host "sent"
                } catch {
                    Write-Log "Teams notification failed: $_"
                    Write-Host "  Teams     " -ForegroundColor Red -NoNewline
                    Write-Host "failed"
                }
            } else {
                Write-Host "  Teams     " -ForegroundColor Yellow -NoNewline
                Write-Host "skipped " -NoNewline
                Write-Host "(no card JSON)" -ForegroundColor DarkGray
                Write-Log "Teams skipped -- card file not found."
            }
        } else {
            Write-Host "  Teams     " -ForegroundColor Yellow -NoNewline
            Write-Host "skipped " -NoNewline
            Write-Host "(webhook not set)" -ForegroundColor DarkGray
        }
    }

    # -- Post-processing: Slack notification ---------------
    if ($Slack) {
        $slackScript = Join-Path $ScriptDir "scripts\notify-slack.ps1"
        if ((Test-Path $slackScript) -and $env:AI_BRIEFING_SLACK_WEBHOOK) {
            if (Test-Path $CardFile) {
                Write-Host "  Sending to Slack..." -ForegroundColor DarkGray
                Write-Log "Sending Slack notification..."
                try {
                    & $slackScript -All -CardFile $CardFile
                    Write-Log "Slack notification sent."
                    Write-Host "  Slack     " -ForegroundColor Green -NoNewline
                    Write-Host "sent"
                } catch {
                    Write-Log "Slack notification failed: $_"
                    Write-Host "  Slack     " -ForegroundColor Red -NoNewline
                    Write-Host "failed"
                }
            } else {
                Write-Host "  Slack     " -ForegroundColor Yellow -NoNewline
                Write-Host "skipped " -NoNewline
                Write-Host "(no card JSON)" -ForegroundColor DarkGray
                Write-Log "Slack skipped -- card file not found."
            }
        } else {
            Write-Host "  Slack     " -ForegroundColor Yellow -NoNewline
            Write-Host "skipped " -NoNewline
            Write-Host "(webhook not set)" -ForegroundColor DarkGray
        }
    }
} catch {
    Write-Log "Custom brief FAILED with error: $_"
    Write-Host ""
    Write-Host "  FAILED" -ForegroundColor Red -NoNewline
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "  Done." -ForegroundColor Green -NoNewline
Write-Host "  Log: $LogFile" -ForegroundColor DarkGray
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""
