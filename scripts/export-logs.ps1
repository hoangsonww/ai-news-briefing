#Requires -Version 5.1
Set-StrictMode -Version Latest

# export-logs.ps1 — Archive logs into a compressed zip on Windows.
# Exports all logs (or a date range) to a .zip archive.
# Usage:
#   .\scripts\export-logs.ps1                                    # All logs
#   .\scripts\export-logs.ps1 -From 2026-03-01                  # From date
#   .\scripts\export-logs.ps1 -From 2026-03-01 -To 2026-03-07  # Range
#   .\scripts\export-logs.ps1 -OutputDir ~\backup               # Custom output

param(
    [string]$From = "",
    [string]$To = "",
    [string]$OutputDir = ""
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$LogDir = Join-Path $ScriptDir "logs"
if (-not $OutputDir) { $OutputDir = $ScriptDir }

if (-not (Test-Path $LogDir)) {
    Write-Host "No logs directory found at $LogDir"
    exit 1
}

$logs = Get-ChildItem -Path $LogDir -Filter "*.log" -File
$matched = @()

foreach ($log in $logs) {
    $baseName = $log.BaseName

    # Non-date logs: include only if no range filter
    if ($baseName -notmatch '^\d{4}-\d{2}-\d{2}$') {
        if (-not $From -and -not $To) { $matched += $log }
        continue
    }

    if ($From -and $baseName -lt $From) { continue }
    if ($To -and $baseName -gt $To) { continue }
    $matched += $log
}

if ($matched.Count -eq 0) {
    Write-Host "No logs matched the specified criteria."
    exit 0
}

$date = Get-Date -Format "yyyy-MM-dd"
$rangeLabel = ""
if ($From) { $rangeLabel += "_from-$From" }
if ($To) { $rangeLabel += "_to-$To" }
$archiveName = "ai-briefing-logs_${date}${rangeLabel}.zip"
$archivePath = Join-Path $OutputDir $archiveName

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Remove existing archive if present
if (Test-Path $archivePath) { Remove-Item $archivePath -Force }

Compress-Archive -Path ($matched | ForEach-Object { $_.FullName }) -DestinationPath $archivePath

$sizeKB = [math]::Round((Get-Item $archivePath).Length / 1024, 1)
$size = if ($sizeKB -ge 1024) { "{0:N1} MB" -f ($sizeKB / 1024) } else { "{0:N1} KB" -f $sizeKB }

Write-Host ""
Write-Host "  Exported $($matched.Count) log file(s) to:"
Write-Host "  $archivePath ($size)"
Write-Host ""
