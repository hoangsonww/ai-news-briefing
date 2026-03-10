#Requires -Version 5.1
Set-StrictMode -Version Latest

# uninstall.ps1 — Fully remove AI News Briefing scheduler and optional cleanup.
# Usage:
#   .\scripts\uninstall.ps1          # Remove scheduler only
#   .\scripts\uninstall.ps1 -All     # Remove scheduler + logs + backups

param(
    [switch]$All
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)

Write-Host ""
Write-Host "  AI News Briefing - Uninstall" -ForegroundColor White
Write-Host "  ============================="
Write-Host ""

# --- Remove Windows Scheduled Task ---
try {
    $task = Get-ScheduledTask -TaskName "AiNewsBriefing" -ErrorAction Stop
    Unregister-ScheduledTask -TaskName "AiNewsBriefing" -Confirm:$false
    Write-Host "  [OK] Scheduled task removed" -ForegroundColor Green
} catch {
    Write-Host "  [--] Scheduled task was not found" -ForegroundColor DarkGray
}

# --- Remove Logs & Backups ---
if ($All) {
    Write-Host ""
    Write-Host "  Cleaning up files..."

    $logsDir = Join-Path $ScriptDir "logs"
    if (Test-Path $logsDir) {
        Remove-Item $logsDir -Recurse -Force
        Write-Host "  [OK] logs\ directory removed" -ForegroundColor Green
    }

    $backupsDir = Join-Path $ScriptDir "backups"
    if (Test-Path $backupsDir) {
        Remove-Item $backupsDir -Recurse -Force
        Write-Host "  [OK] backups\ directory removed" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  Uninstall complete."
Write-Host "  The project files remain in: $ScriptDir"
Write-Host "  To fully remove, delete the directory manually."
Write-Host ""
