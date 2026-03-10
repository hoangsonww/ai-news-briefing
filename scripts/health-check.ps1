#Requires -Version 5.1
Set-StrictMode -Version Latest

# health-check.ps1 — Verify the entire AI News Briefing setup on Windows.
# Checks: Claude CLI, prompt structure, scheduler, logs directory, Notion config.

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
$Pass = 0; $Fail = 0; $Warn = 0

function Write-Check {
    param([string]$Name, [string]$Status, [string]$Detail)
    $color = switch ($Status) {
        "OK"   { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
    }
    $label = if ($Detail) { "$Status`: $Detail" } else { $Status }
    Write-Host ("  {0,-40} " -f $Name) -NoNewline
    Write-Host $label -ForegroundColor $color
}

function Check-Pass { param([string]$Name) $script:Pass++; Write-Check $Name "OK" }
function Check-Fail { param([string]$Name, [string]$Detail) $script:Fail++; Write-Check $Name "FAIL" $Detail }
function Check-Warn { param([string]$Name, [string]$Detail) $script:Warn++; Write-Check $Name "WARN" $Detail }

Write-Host ""
Write-Host "  AI News Briefing - Health Check" -ForegroundColor White
Write-Host "  ================================"
Write-Host ""

# --- Claude CLI ---
Write-Host "  [Claude CLI]" -ForegroundColor DarkGray
if (Test-Path $Claude) {
    Check-Pass "Claude binary exists"
    try {
        $ver = & $Claude --version 2>&1 | Select-Object -First 1
        Check-Pass "Claude responds ($ver)"
    } catch {
        Check-Fail "Claude responds" "binary found but --version failed"
    }
} else {
    Check-Fail "Claude binary exists" "not found at $Claude"
    Check-Fail "Claude responds" "binary missing"
}
Write-Host ""

# --- Project Files ---
Write-Host "  [Project Files]" -ForegroundColor DarkGray
foreach ($f in @("prompt.md","briefing.sh","briefing.ps1","com.ainews.briefing.plist","install-task.ps1","Makefile")) {
    $path = Join-Path $ScriptDir $f
    if (Test-Path $path) { Check-Pass $f } else { Check-Fail $f "missing" }
}
Write-Host ""

# --- Prompt Structure ---
Write-Host "  [Prompt Structure]" -ForegroundColor DarkGray
$promptPath = Join-Path $ScriptDir "prompt.md"
$promptContent = if (Test-Path $promptPath) { Get-Content $promptPath -Raw } else { "" }

foreach ($section in @("Step 0","Step 1","Step 2","Step 3","Topics to Search","Date Attribution","Notion Formatting")) {
    if ($promptContent -match [regex]::Escape($section)) {
        Check-Pass "prompt.md contains '$section'"
    } else {
        Check-Warn "prompt.md contains '$section'" "section not found"
    }
}

$topicMatches = [regex]::Matches($promptContent, '^\d\.', [System.Text.RegularExpressions.RegexOptions]::Multiline)
$topicCount = $topicMatches.Count
if ($topicCount -ge 9) { Check-Pass "Topic count ($topicCount topics)" }
else { Check-Warn "Topic count ($topicCount topics)" "expected 9+" }

if ($promptContent -match "data_source_id") { Check-Pass "Notion data_source_id present" }
else { Check-Fail "Notion data_source_id present" "missing from prompt.md" }
Write-Host ""

# --- Logs ---
Write-Host "  [Logs]" -ForegroundColor DarkGray
$LogDir = Join-Path $ScriptDir "logs"
if (Test-Path $LogDir) {
    Check-Pass "logs\ directory exists"
    $logs = Get-ChildItem -Path $LogDir -Filter "*.log" -File -ErrorAction SilentlyContinue
    if ($logs.Count -gt 0) {
        $latest = $logs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Check-Pass "$($logs.Count) log file(s), latest: $($latest.Name)"
    } else {
        Check-Warn "Log files" "directory exists but no logs yet"
    }
} else {
    Check-Warn "logs\ directory exists" "will be created on first run"
}
Write-Host ""

# --- Windows Scheduler ---
Write-Host "  [Windows Scheduler]" -ForegroundColor DarkGray
try {
    $task = Get-ScheduledTask -TaskName "AiNewsBriefing" -ErrorAction Stop
    Check-Pass "Scheduled task registered"
    $state = $task.State
    if ($state -eq "Ready") { Check-Pass "Task state: $state" }
    else { Check-Warn "Task state: $state" "expected Ready" }

    $trigger = $task.Triggers | Select-Object -First 1
    if ($trigger) {
        $time = $trigger.StartBoundary
        Check-Pass "Trigger configured ($time)"
    }
} catch {
    Check-Warn "Scheduled task registered" "not found - run: make install"
}
Write-Host ""

# --- Summary ---
$Total = $Pass + $Fail + $Warn
Write-Host "  --------------------------------"
Write-Host ("  Total: {0} checks - " -f $Total) -NoNewline
Write-Host "$Pass passed" -ForegroundColor Green -NoNewline
if ($Warn -gt 0) { Write-Host ", $Warn warnings" -ForegroundColor Yellow -NoNewline }
if ($Fail -gt 0) { Write-Host ", $Fail failed" -ForegroundColor Red -NoNewline }
Write-Host ""
Write-Host ""

if ($Fail -gt 0) { exit 1 }
