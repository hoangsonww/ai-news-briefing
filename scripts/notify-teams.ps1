#Requires -Version 5.1

# notify-teams.ps1 — Post today's AI briefing to a Teams channel via webhook.
# Usage:
#   .\scripts\notify-teams.ps1                          # Auto-detect from today's log
#   .\scripts\notify-teams.ps1 -WebhookUrl "https://..."  # Override webhook URL
#   .\scripts\notify-teams.ps1 -LogFile "path\to.log"     # Use specific log file

param(
    [string]$WebhookUrl = $env:AI_BRIEFING_TEAMS_WEBHOOK,
    [string]$LogFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Date = Get-Date -Format "yyyy-MM-dd"

if (-not $LogFile) {
    $LogFile = Join-Path (Join-Path $ScriptDir "logs") "$Date.log"
}

if (-not $WebhookUrl) {
    Write-Error "No webhook URL. Set AI_BRIEFING_TEAMS_WEBHOOK env var or pass -WebhookUrl."
    exit 1
}

if (-not (Test-Path $LogFile)) {
    Write-Error "Log file not found: $LogFile"
    exit 1
}

$logContent = Get-Content $LogFile -Raw -Encoding utf8

if ($logContent -notmatch "Briefing complete") {
    Write-Host "Briefing did not complete successfully. Skipping Teams notification."
    exit 0
}

# Use shared Python builder for the Adaptive Card JSON
$builderScript = Join-Path (Join-Path $ScriptDir "scripts") "build-teams-card.py"
if (-not (Test-Path $builderScript)) {
    Write-Error "build-teams-card.py not found at $builderScript"
    exit 1
}

# Build JSON via Python using Process API for clean stdout capture
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "python3"
$psi.Arguments = "`"$builderScript`" `"$LogFile`""
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$jsonPayload = $proc.StandardOutput.ReadToEnd()
$stderrOutput = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()

if ($proc.ExitCode -ne 0) {
    Write-Error "Failed to build Teams card: $stderrOutput"
    exit 1
}

$bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)

try {
    $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $bytes -ContentType "application/json; charset=utf-8"
    Write-Host "Teams notification sent successfully."
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "Teams notification failed (HTTP $status): $_"
    exit 1
}
