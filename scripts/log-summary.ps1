#Requires -Version 5.1
Set-StrictMode -Version Latest

# log-summary.ps1 — Summarize recent briefing runs on Windows.
# Shows date, status (pass/fail), file size for each log.
# Usage: .\scripts\log-summary.ps1 [-Days 14]

param(
    [int]$Days = 14
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$LogDir = Join-Path $ScriptDir "logs"

Write-Host ""
Write-Host "  AI News Briefing - Run Summary (last $Days days)" -ForegroundColor White
Write-Host "  =================================================="
Write-Host ""

if (-not (Test-Path $LogDir)) {
    Write-Host "  No logs directory found."
    exit 0
}

$logs = Get-ChildItem -Path $LogDir -Filter "*.log" -File |
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}\.log$' } |
    Sort-Object Name -Descending |
    Select-Object -First $Days

if ($logs.Count -eq 0) {
    Write-Host "  No dated log files found."
    exit 0
}

Write-Host ("  {0,-14} {1,-10} {2,-10} {3}" -f "Date", "Status", "Size", "Details")
Write-Host ("  {0,-14} {1,-10} {2,-10} {3}" -f "----------", "------", "------", "-------")

$Success = 0; $Failed = 0; $Total = 0

foreach ($log in $logs) {
    $Total++
    $date = $log.BaseName
    $sizeKB = [math]::Round($log.Length / 1024, 1)
    $size = if ($sizeKB -ge 1024) { "{0:N1} MB" -f ($sizeKB / 1024) } else { "{0:N1} KB" -f $sizeKB }
    $content = Get-Content $log.FullName -Raw -ErrorAction SilentlyContinue

    if ($content -match "Briefing complete") {
        $Success++
        Write-Host ("  {0,-14} " -f $date) -NoNewline
        Write-Host ("{0,-10} " -f "PASS") -ForegroundColor Green -NoNewline
        Write-Host ("{0,-10} " -f $size) -NoNewline
        Write-Host "Check Notion for report"
    } elseif ($content -match "FAILED") {
        $Failed++
        $detail = ($content -split "`n" | Select-String "FAILED" | Select-Object -Last 1).ToString().Trim()
        Write-Host ("  {0,-14} " -f $date) -NoNewline
        Write-Host ("{0,-10} " -f "FAIL") -ForegroundColor Red -NoNewline
        Write-Host ("{0,-10} " -f $size) -NoNewline
        Write-Host $detail
    } else {
        Write-Host ("  {0,-14} " -f $date) -NoNewline
        Write-Host ("{0,-10} " -f "????") -ForegroundColor DarkGray -NoNewline
        Write-Host ("{0,-10} " -f $size) -NoNewline
        Write-Host "No completion marker found"
    }
}

$Incomplete = $Total - $Success - $Failed
Write-Host ""
Write-Host "  --------------------------------"
Write-Host ("  {0} runs: " -f $Total) -NoNewline
Write-Host "$Success succeeded" -ForegroundColor Green -NoNewline
if ($Failed -gt 0) { Write-Host ", $Failed failed" -ForegroundColor Red -NoNewline }
if ($Incomplete -gt 0) { Write-Host ", $Incomplete unknown" -ForegroundColor DarkGray -NoNewline }
Write-Host ""
Write-Host ""
