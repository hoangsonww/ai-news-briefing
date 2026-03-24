#Requires -Version 5.1

# notify-slack.ps1 — Convert a Teams Adaptive Card JSON to Slack Block Kit and POST it.
#
# Usage:
#   .\scripts\notify-slack.ps1                          # Post to first URL in env var
#   .\scripts\notify-slack.ps1 -WebhookUrl "https://..."
#   .\scripts\notify-slack.ps1 -All                     # Post to ALL semicolon-separated URLs
#   .\scripts\notify-slack.ps1 -CardFile "path\to\card.json"
#
# Multiple webhooks: set AI_BRIEFING_SLACK_WEBHOOK to semicolon-separated URLs.
# By default only the first URL is used. Pass -All to post to every URL.

param(
    [string]$WebhookUrl = $env:AI_BRIEFING_SLACK_WEBHOOK,
    [string]$CardFile = "",
    [switch]$All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Date = Get-Date -Format "yyyy-MM-dd"

if (-not $CardFile) {
    $CardFile = Join-Path (Join-Path $ScriptDir "logs") "$Date-card.json"
}

# Resolve relative paths against $PWD (ReadAllBytes resolves against System32, not $PWD)
if (-not [System.IO.Path]::IsPathRooted($CardFile)) {
    $CardFile = Join-Path (Get-Location).Path $CardFile
}

if (-not $WebhookUrl) {
    Write-Error "No webhook URL. Set AI_BRIEFING_SLACK_WEBHOOK or pass -WebhookUrl."
    exit 1
}

if (-not (Test-Path $CardFile)) {
    Write-Error "Card file not found: $CardFile"
    exit 1
}

# Convert Teams card JSON to Slack Block Kit JSON
$Converter = Join-Path $ScriptDir "scripts\teams-to-slack.py"
if (-not (Test-Path $Converter)) {
    Write-Error "Converter script not found: $Converter"
    exit 1
}

$TmpFile = [System.IO.Path]::GetTempFileName()
try {
    $convResult = & python3 $Converter $CardFile $TmpFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to convert card to Slack format: $convResult"
        exit 1
    }

    # Validate the converted payload
    try {
        $null = Get-Content $TmpFile -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
        Write-Error "Converted Slack payload is not valid JSON: $_"
        exit 1
    }

    $bytes = [System.IO.File]::ReadAllBytes($TmpFile)

    # Split on semicolons, trim whitespace, drop empties
    $allUrls = @($WebhookUrl -split ";" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })

    if ($allUrls.Count -eq 0) {
        Write-Error "No valid webhook URLs found."
        exit 1
    }

    # Default: first URL only. -All: every URL.
    if ($All) {
        [array]$urls = $allUrls
    } else {
        [array]$urls = @($allUrls[0])
    }

    if (-not $All -and $allUrls.Count -gt 1) {
        Write-Host "Using first Slack webhook URL (pass -All to post to all $($allUrls.Count) URLs)."
    }

    $failed = 0
    foreach ($url in $urls) {
        try {
            $resp = Invoke-WebRequest -Uri $url -Method Post -Body $bytes -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 30
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
                Write-Host "Slack notification sent (HTTP $($resp.StatusCode))."
            } else {
                Write-Warning "Slack notification failed for $url (HTTP $($resp.StatusCode)): $($resp.Content)"
                $failed++
            }
        } catch [System.Net.WebException] {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            Write-Warning "Slack notification failed for $url (HTTP $status): $($_.Exception.Message)"
            $failed++
        } catch {
            Write-Warning "Slack notification failed for $url : $($_.Exception.Message)"
            $failed++
        }
    }

    if ($failed -eq $urls.Count) {
        Write-Error "All $failed Slack webhook(s) failed."
        exit 1
    }

    if ($failed -gt 0) {
        Write-Host "$failed of $($urls.Count) Slack webhook(s) failed. Check warnings above."
    }
} finally {
    Remove-Item $TmpFile -Force -ErrorAction SilentlyContinue
}
