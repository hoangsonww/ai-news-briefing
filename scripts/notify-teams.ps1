#Requires -Version 5.1

# notify-teams.ps1 — POST a pre-built Adaptive Card JSON to Teams webhook.
# The AI generates the card JSON directly. This script just sends it.
#
# Usage:
#   .\scripts\notify-teams.ps1
#   .\scripts\notify-teams.ps1 -WebhookUrl "https://..."
#   .\scripts\notify-teams.ps1 -CardFile "path\to\card.json"

param(
    [string]$WebhookUrl = $env:AI_BRIEFING_TEAMS_WEBHOOK,
    [string]$CardFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Date = Get-Date -Format "yyyy-MM-dd"

if (-not $CardFile) {
    $CardFile = Join-Path (Join-Path $ScriptDir "logs") "$Date-card.json"
}

if (-not $WebhookUrl) {
    Write-Error "No webhook URL. Set AI_BRIEFING_TEAMS_WEBHOOK or pass -WebhookUrl."
    exit 1
}

if (-not (Test-Path $CardFile)) {
    Write-Error "Card file not found: $CardFile"
    exit 1
}

# Validate JSON before sending
try {
    $null = Get-Content $CardFile -Raw -Encoding utf8 | ConvertFrom-Json
} catch {
    Write-Error "$CardFile is not valid JSON: $_"
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($CardFile)

try {
    $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $bytes -ContentType "application/json; charset=utf-8"
    Write-Host "Teams notification sent successfully."
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Error "Teams notification failed (HTTP $status): $_"
    exit 1
}
