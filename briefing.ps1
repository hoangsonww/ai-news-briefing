#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogDir = Join-Path $ScriptDir "logs"
$Date = Get-Date -Format "yyyy-MM-dd"
$Time = Get-Date -Format "HH:mm:ss"
$LogFile = Join-Path $LogDir "$Date.log"
$Claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe"

# Ensure we can run even if Claude Code is open
$env:CLAUDECODE = $null

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

try {
    $output = & $Claude -p `
        --model sonnet `
        --dangerously-skip-permissions `
        --max-budget-usd 2.00 `
        $Prompt 2>&1

    $output | Out-File -FilePath $LogFile -Append -Encoding utf8
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Log "Briefing complete. Check Notion for today's report."

        # Post summary to Teams channel if webhook is configured
        $teamsScript = Join-Path $ScriptDir "scripts\notify-teams.ps1"
        if ((Test-Path $teamsScript) -and $env:AI_BRIEFING_TEAMS_WEBHOOK) {
            Write-Log "Sending Teams notification..."
            try {
                & $teamsScript -LogFile $LogFile
                Write-Log "Teams notification sent."
            } catch {
                Write-Log "Teams notification failed: $_"
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
