#Requires -Version 5.1
Set-StrictMode -Version Latest

# cost-report.ps1 — Estimate API costs from log files on Windows.
# Usage:
#   .\scripts\cost-report.ps1               # Current month
#   .\scripts\cost-report.ps1 -Month 03     # Specific month
#   .\scripts\cost-report.ps1 -All          # All time

param(
    [string]$Month = "",
    [switch]$All
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$LogDir = Join-Path $ScriptDir "logs"
$Year = (Get-Date).Year.ToString()

if (-not $Month -and -not $All) {
    $Month = (Get-Date).ToString("MM")
}

if (-not (Test-Path $LogDir)) {
    Write-Host "No logs directory found."
    exit 0
}

Write-Host ""
Write-Host "  AI News Briefing - Cost Report" -ForegroundColor White
Write-Host "  ==============================="
Write-Host ""

$TotalRuns = 0; $SuccessRuns = 0; $FailedRuns = 0; $TotalSize = 0

$logs = Get-ChildItem -Path $LogDir -Filter "*.log" -File |
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}\.log$' }

foreach ($log in $logs) {
    $baseName = $log.BaseName

    if ($Month) {
        $logYear = $baseName.Substring(0, 4)
        $logMonth = $baseName.Substring(5, 2)
        if ($logYear -ne $Year -or $logMonth -ne $Month) { continue }
    }

    $TotalRuns++
    $TotalSize += $log.Length
    $content = Get-Content $log.FullName -Raw -ErrorAction SilentlyContinue

    if ($content -match "Briefing complete") { $SuccessRuns++ }
    elseif ($content -match "FAILED") { $FailedRuns++ }
}

if ($TotalRuns -eq 0) {
    $period = if ($Month) { "$Year-$Month" } else { "all time" }
    Write-Host "  No runs found for $period."
    Write-Host ""
    exit 0
}

$periodLabel = if ($Month) { "$Year-$Month" } else { "all time" }
$sizeMB = [math]::Round($TotalSize / 1MB, 1)

$estLow = [math]::Round($SuccessRuns * 0.70, 2)
$estAvg = [math]::Round($SuccessRuns * 1.05, 2)
$estHigh = [math]::Round($SuccessRuns * 1.40, 2)
$estMax = [math]::Round($TotalRuns * 2.00, 2)

Write-Host ("  {0,-28} {1}" -f "Period:", $periodLabel)
Write-Host ("  {0,-28} {1}" -f "Total runs:", $TotalRuns)
Write-Host ("  {0,-28} {1}" -f "Successful:", $SuccessRuns)
Write-Host ("  {0,-28} {1}" -f "Failed:", $FailedRuns)
Write-Host ("  {0,-28} {1}" -f "Total log size:", "$sizeMB MB")
Write-Host ""
Write-Host "  Cost Estimates (Sonnet model)" -ForegroundColor White
Write-Host "  -----------------------------"
Write-Host ("  {0,-28} {1}" -f "Low estimate (`$0.70/run):", "`$$estLow")
Write-Host ("  {0,-28} {1}" -f "Average (`$1.05/run):", "`$$estAvg")
Write-Host ("  {0,-28} {1}" -f "High estimate (`$1.40/run):", "`$$estHigh")
Write-Host ("  {0,-28} {1}" -f "Budget cap (`$2.00/run):", "`$$estMax max")
Write-Host ""

if ($FailedRuns -gt 0) {
    $failRate = [math]::Round($FailedRuns * 100 / $TotalRuns)
    Write-Host "  Note: ${failRate}% failure rate. Failed runs still consume some API budget." -ForegroundColor Yellow
    Write-Host ""
}
