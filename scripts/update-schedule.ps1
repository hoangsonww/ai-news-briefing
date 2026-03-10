#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# update-schedule.ps1 — Change the daily briefing schedule time (Windows).
# Re-registers the Task Scheduler task with a new time.
# Usage: .\scripts\update-schedule.ps1 -Hour 7 -Minute 30

param(
    [Parameter(Mandatory)]
    [ValidateRange(0, 23)]
    [int]$Hour,

    [ValidateRange(0, 59)]
    [int]$Minute = 0
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$InstallerScript = Join-Path $ScriptDir "install-task.ps1"

Write-Host ""
Write-Host ("  Updating schedule to {0:D2}:{1:D2}..." -f $Hour, $Minute)

if (-not (Test-Path $InstallerScript)) {
    Write-Host "  ERROR: install-task.ps1 not found at $InstallerScript" -ForegroundColor Red
    exit 1
}

# Use the existing installer (it's idempotent — removes old task first)
& $InstallerScript -Hour $Hour -Minute $Minute

Write-Host ""
Write-Host ("  New schedule: daily at {0:D2}:{1:D2}" -f $Hour, $Minute)
Write-Host "  Verify: schtasks /query /tn AiNewsBriefing"
Write-Host ""
