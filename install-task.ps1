#Requires -Version 5.1
<#
.SYNOPSIS
    Registers (or re-registers) the AI News Briefing scheduled task.
.DESCRIPTION
    Creates a Windows Task Scheduler task that runs briefing.ps1 daily at 8:00 AM.
    Run this script from an elevated (admin) PowerShell prompt OR as your own user
    (the task will run under your account).
.EXAMPLE
    .\install-task.ps1
    .\install-task.ps1 -Hour 7 -Minute 30
#>
param(
    [int]$Hour = 8,
    [int]$Minute = 0
)

$ErrorActionPreference = "Stop"

$TaskName = "AiNewsBriefing"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BriefingScript = Join-Path $ScriptDir "briefing.ps1"

if (-not (Test-Path $BriefingScript)) {
    Write-Error "briefing.ps1 not found at $BriefingScript"
    exit 1
}

# Remove existing task if present
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing '$TaskName' task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$BriefingScript`"" `
    -WorkingDirectory $ScriptDir

$trigger = New-ScheduledTaskTrigger -Daily -At ("{0:D2}:{1:D2}" -f $Hour, $Minute)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Daily AI news briefing via Claude Code CLI" `
    -RunLevel Limited

Write-Host ""
Write-Host "Task '$TaskName' registered to run daily at $("{0:D2}:{1:D2}" -f $Hour, $Minute)."
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  Run now:    schtasks /run /tn $TaskName"
Write-Host "  Check:      schtasks /query /tn $TaskName"
Write-Host "  Delete:     schtasks /delete /tn $TaskName /f"
$logExample = Join-Path $ScriptDir "logs" | Join-Path -ChildPath "$(Get-Date -Format 'yyyy-MM-dd').log"
Write-Host "  View log:   Get-Content `"$logExample`""
