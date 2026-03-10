#Requires -Version 5.1
Set-StrictMode -Version Latest

# notify.ps1 — Send a Windows toast notification after briefing completes.
# Reads today's log to determine success/failure and sends appropriate notification.
# Usage:
#   .\scripts\notify.ps1                     # Auto-detect from log
#   .\scripts\notify.ps1 -Status success     # Force success
#   .\scripts\notify.ps1 -Status custom -Message "Test notification"

param(
    [ValidateSet("auto","success","failure","custom")]
    [string]$Status = "auto",
    [string]$Message = ""
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$LogDir = Join-Path $ScriptDir "logs"
$Date = Get-Date -Format "yyyy-MM-dd"
$LogFile = Join-Path $LogDir "$Date.log"
$Title = "AI News Briefing"

# Auto-detect status from log
if ($Status -eq "auto") {
    if (-not (Test-Path $LogFile)) {
        $Status = "failure"
        if (-not $Message) { $Message = "No log file found for today." }
    } else {
        $content = Get-Content $LogFile -Raw -ErrorAction SilentlyContinue
        if ($content -match "Briefing complete") {
            $Status = "success"
        } elseif ($content -match "FAILED") {
            $Status = "failure"
            if (-not $Message) {
                $failLine = ($content -split "`n" | Select-String "FAILED" | Select-Object -Last 1)
                $Message = if ($failLine) { $failLine.ToString().Trim() } else { "Check log for details." }
            }
        } else {
            $Status = "failure"
            if (-not $Message) { $Message = "Run may still be in progress or ended without status." }
        }
    }
}

switch ($Status) {
    "success" {
        if (-not $Message) { $Message = "Briefing complete. Check Notion for today's report." }
    }
    "failure" {
        if (-not $Message) { $Message = "Briefing failed. Check logs for details." }
    }
    "custom" {
        if (-not $Message) { $Message = "No message provided." }
    }
}

# Try BurntToast module first (best experience)
if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
    Import-Module BurntToast
    $icon = if ($Status -eq "failure") { "Warning" } else { "Default" }
    New-BurntToastNotification -Text $Title, $Message -AppLogo $null
    Write-Host "Toast notification sent (BurntToast): $Message"
    return
}

# Fallback: Windows Runtime toast
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

    $template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$Title</text>
      <text>$([System.Security.SecurityElement]::Escape($Message))</text>
    </binding>
  </visual>
</toast>
"@

    $xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $xml.LoadXml($template)

    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("AI News Briefing")
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    $notifier.Show($toast)

    Write-Host "Toast notification sent (WinRT): $Message"
} catch {
    # Final fallback: console output
    $color = if ($Status -eq "failure") { "Red" } else { "Green" }
    Write-Host ""
    Write-Host "  [$Title]" -ForegroundColor $color
    Write-Host "  $Message"
    Write-Host ""
    Write-Host "  (Toast notification unavailable. Install BurntToast for better notifications:" -ForegroundColor DarkGray
    Write-Host "   Install-Module -Name BurntToast)" -ForegroundColor DarkGray
}
