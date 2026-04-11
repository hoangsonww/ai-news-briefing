#Requires -Version 5.1

<#
.SYNOPSIS
    Deep-research a topic and produce a comprehensive news briefing.
.DESCRIPTION
    Uses an AI CLI engine in headless mode to conduct multi-agent deep research
    on a user-defined topic, then optionally publishes to Notion, Obsidian, Teams, and/or Slack.
    Supports Claude Code, Codex, Gemini, and GitHub Copilot.
.PARAMETER Topic
    The topic to research. If omitted, enters interactive mode.
.PARAMETER Cli
    AI engine: claude, codex, gemini, copilot. Default: AI_BRIEFING_CLI env or claude.
.PARAMETER Notion
    Publish the briefing to Notion.
.PARAMETER Obsidian
    Publish the briefing to an Obsidian vault (requires AI_BRIEFING_OBSIDIAN_VAULT env var).
.PARAMETER Teams
    Send a summary card to Microsoft Teams.
.PARAMETER Slack
    Send a summary card to Slack.
.EXAMPLE
    .\custom-brief.ps1 -Topic "AI in healthcare" -Cli codex -Notion -Obsidian -Teams
.EXAMPLE
    .\custom-brief.ps1 -Topic "quantum computing" -Notion -Obsidian
.EXAMPLE
    .\custom-brief.ps1   # interactive mode
#>

param(
    [string]$Topic = "",
    [ValidateSet("claude", "codex", "gemini", "copilot", "")]
    [string]$Cli = "",
    [switch]$Notion,
    [switch]$Obsidian,
    [switch]$Teams,
    [switch]$Slack
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogDir = Join-Path $ScriptDir "logs"
$Date = Get-Date -Format "yyyy-MM-dd"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

# Ensure we can run even if Claude Code is open
$env:CLAUDECODE = $null

# Refresh persistent env vars from registry
foreach ($name in @("AI_BRIEFING_TEAMS_WEBHOOK", "AI_BRIEFING_SLACK_WEBHOOK", "AI_BRIEFING_CLI", "AI_BRIEFING_MODEL")) {
    $val = [Environment]::GetEnvironmentVariable($name, "User")
    if ($val) { [Environment]::SetEnvironmentVariable($name, $val, "Process") }
}

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# -- CLI Engine Registry ---------------------------------------
$SupportedClis = @("claude", "codex", "gemini", "copilot")

function Resolve-CliBinary {
    param([string]$CliName)
    switch ($CliName) {
        "claude" {
            foreach ($p in @(
                (Join-Path $env:USERPROFILE ".local\bin\claude.exe"),
                (Join-Path $env:USERPROFILE ".local\bin\claude")
            )) {
                if (Test-Path $p) { return $p }
            }
            $cmd = Get-Command "claude" -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            return $null
        }
        "codex" {
            $cmd = Get-Command "codex" -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            return $null
        }
        "gemini" {
            $cmd = Get-Command "gemini" -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            return $null
        }
        "copilot" {
            $gh = Get-Command "gh" -ErrorAction SilentlyContinue
            if ($gh) {
                try {
                    $exts = & gh extension list 2>$null
                    if ($exts -match "copilot") { return $gh.Source }
                } catch {}
            }
            $cmd = Get-Command "copilot" -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            return $null
        }
        default { return $null }
    }
}

function Get-CliDisplayName {
    param([string]$CliName)
    switch ($CliName) {
        "claude"  { "Claude Code" }
        "codex"   { "OpenAI Codex" }
        "gemini"  { "Gemini CLI" }
        "copilot" { "GitHub Copilot" }
        default   { $CliName }
    }
}

function Invoke-Engine {
    param(
        [string]$CliName,
        [string]$Binary,
        [string]$Prompt,
        [string]$LogPath
    )

    $model = if ($env:AI_BRIEFING_MODEL) { $env:AI_BRIEFING_MODEL } else { "opus" }

    switch ($CliName) {
        "claude" {
            & $Binary -p --model $model --dangerously-skip-permissions $Prompt 2>&1 | ForEach-Object {
                Write-Host $_
                $_ | Out-File -FilePath $LogPath -Append -Encoding utf8
            }
        }
        "codex" {
            & $Binary -q --full-auto $Prompt 2>&1 | ForEach-Object {
                Write-Host $_
                $_ | Out-File -FilePath $LogPath -Append -Encoding utf8
            }
        }
        "gemini" {
            & $Binary -p $Prompt 2>&1 | ForEach-Object {
                Write-Host $_
                $_ | Out-File -FilePath $LogPath -Append -Encoding utf8
            }
        }
        "copilot" {
            if ($Binary -match '[/\\]gh(\.exe)?$') {
                & $Binary copilot -p $Prompt 2>&1 | ForEach-Object {
                    Write-Host $_
                    $_ | Out-File -FilePath $LogPath -Append -Encoding utf8
                }
            } else {
                & $Binary -p $Prompt 2>&1 | ForEach-Object {
                    Write-Host $_
                    $_ | Out-File -FilePath $LogPath -Append -Encoding utf8
                }
            }
        }
    }
    return $(if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 })
}

# -- Banner ----------------------------------------------------
function Write-Banner {
    $d = "DarkGray"
    $c = "Cyan"
    Write-Host ""
    Write-Host "   _____                                                                 _____ " -ForegroundColor $d
    Write-Host "  ( ___ )---------------------------------------------------------------( ___ )" -ForegroundColor $d
    Write-Host "   |   |                                                                 |   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host "     _    ___   _   _                     ____       _       __  " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host "    / \  |_ _| | \ | | _____      _____  | __ ) _ __(_) ___ / _| " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host "   / _ \  | |  |  \| |/ _ \ \ /\ / / __| |  _ \| '__| |/ _ \ |_  " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host "  / ___ \ | |  | |\  |  __/\ V  V /\__ \ | |_) | |  | |  __/  _| " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |   |" -ForegroundColor $d -NoNewline; Write-Host " /_/   \_\___| |_| \_|\___| \_/\_/ |___/ |____/|_|  |_|\___|_|   " -ForegroundColor $c -NoNewline; Write-Host "|   | " -ForegroundColor $d
    Write-Host "   |___|                                                                 |___| " -ForegroundColor $d
    Write-Host "  (_____)---------------------------------------------------------------(_____)  " -ForegroundColor $d
}

# -- Interactive REPL (if no topic provided) -------------------
if (-not $Topic) {
    Write-Banner
    Write-Host ""
    Write-Host "  Interactive Mode" -ForegroundColor Magenta
    Write-Host ""

    # Topic
    Write-Host "  --- Topic -------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  What would you like to research?"
    Write-Host "  > " -NoNewline
    $Topic = Read-Host
    if (-not $Topic) {
        Write-Host "  Error: topic cannot be empty." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    # AI Engine
    Write-Host "  --- AI Engine ---------------------------------------------" -ForegroundColor DarkGray
    $idx = 0
    $defaultIdx = 0
    $defaultCli = ""
    foreach ($c in $SupportedClis) {
        $idx++
        $label = Get-CliDisplayName $c
        $padded = $label.PadRight(16)
        $binary = Resolve-CliBinary -CliName $c
        if ($binary) {
            Write-Host "    " -NoNewline
            Write-Host "$idx)" -ForegroundColor White -NoNewline
            Write-Host " $padded " -NoNewline
            Write-Host "available" -ForegroundColor Green
            if (-not $defaultCli) {
                $defaultCli = $c
                $defaultIdx = $idx
            }
        } else {
            Write-Host "    " -NoNewline
            Write-Host "$idx)" -ForegroundColor White -NoNewline
            Write-Host " $padded " -NoNewline
            Write-Host "not installed" -ForegroundColor Red
        }
    }
    Write-Host ""

    # Check env var for default
    $envCli = $env:AI_BRIEFING_CLI
    if ($envCli) {
        $idx = 0
        foreach ($c in $SupportedClis) {
            $idx++
            if ($c -eq $envCli) { $defaultIdx = $idx; $defaultCli = $envCli; break }
        }
    }

    Write-Host "  Select [1-4, default=$defaultIdx]: " -NoNewline
    $engineChoice = Read-Host
    if (-not $engineChoice) {
        $Cli = $defaultCli
    } else {
        $choiceInt = [int]$engineChoice
        if ($choiceInt -ge 1 -and $choiceInt -le $SupportedClis.Count) {
            $Cli = $SupportedClis[$choiceInt - 1]
        } else {
            Write-Host "  Invalid selection." -ForegroundColor Red
            exit 1
        }
    }
    Write-Host ""

    # Publish destinations
    Write-Host "  --- Publish -----------------------------------------------" -ForegroundColor DarkGray
    $yn = Read-Host "    Notion?   [y/N]"
    if ($yn -match "^[Yy]") { $Notion = [switch]::new($true) }
    $yn = Read-Host "    Obsidian? [y/N]"
    if ($yn -match "^[Yy]") { $Obsidian = [switch]::new($true) }
    $yn = Read-Host "    Teams?    [y/N]"
    if ($yn -match "^[Yy]") { $Teams = [switch]::new($true) }
    $yn = Read-Host "    Slack?  [y/N]"
    if ($yn -match "^[Yy]") { $Slack = [switch]::new($true) }
    Write-Host ""
}

# -- Resolve engine (non-interactive fallback) -----------------
if (-not $Cli) {
    $Cli = if ($env:AI_BRIEFING_CLI) { $env:AI_BRIEFING_CLI } else { "claude" }
}

$EngineBinary = Resolve-CliBinary -CliName $Cli
if (-not $EngineBinary) {
    Write-Host "  ERROR" -ForegroundColor Red -NoNewline
    Write-Host "  Engine '$(Get-CliDisplayName $Cli)' is not installed." -ForegroundColor Red
    exit 1
}

# -- Derive flags ----------------------------------------------
$PublishNotion = if ($Notion) { "true" } else { "false" }
$PublishObsidian = if ($Obsidian) { "true" } else { "false" }
$PublishTeamsSlack = if ($Teams -or $Slack) { "true" } else { "false" }
$PublishTeams = if ($Teams) { "true" } else { "false" }
$PublishSlack = if ($Slack) { "true" } else { "false" }

$LogFile = Join-Path $LogDir "custom-$Timestamp.log"
$CardFile = Join-Path $LogDir "custom-$Timestamp-card.json"

# -- Build the prompt ------------------------------------------
$PromptTemplate = Get-Content -Path (Join-Path $ScriptDir "prompt-custom-brief.md") -Raw

$Prompt = $PromptTemplate.
    Replace('{{TOPIC}}', $Topic).
    Replace('{{DATE}}', $Date).
    Replace('{{TIMESTAMP}}', $Timestamp).
    Replace('{{PUBLISH_NOTION}}', $PublishNotion).
    Replace('{{PUBLISH_OBSIDIAN}}', $PublishObsidian).
    Replace('{{PUBLISH_TEAMS_SLACK}}', $PublishTeamsSlack)

# -- Styled boolean label --------------------------------------
function Write-Flag {
    param([string]$Label, [string]$Value)
    Write-Host "  $Label" -NoNewline
    Write-Host (" " * (10 - $Label.Length)) -NoNewline
    if ($Value -eq "true") {
        Write-Host "yes" -ForegroundColor Green
    } else {
        Write-Host "no" -ForegroundColor DarkGray
    }
}

# -- Print run summary -----------------------------------------
Write-Banner
Write-Host ""
Write-Host "  Deep Research" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Topic     " -NoNewline; Write-Host "$Topic"
Write-Host "  Engine    " -NoNewline; Write-Host "$(Get-CliDisplayName $Cli)" -NoNewline; Write-Host " ($EngineBinary)" -ForegroundColor DarkGray
Write-Flag "Notion" $PublishNotion
Write-Flag "Obsidian" $PublishObsidianFlag
Write-Flag "Teams" $PublishTeams
Write-Flag "Slack" $PublishSlack
Write-Host "  Log       " -NoNewline -ForegroundColor DarkGray; Write-Host "$LogFile" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Launching research agents via $(Get-CliDisplayName $Cli)..." -ForegroundColor Magenta
Write-Host "  This may take a few minutes." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""

# -- Log header ------------------------------------------------
function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    "$Date $ts $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

Write-Log "Custom Brief -- Topic: $Topic"
Write-Log "Engine=$Cli Notion=$PublishNotion Obsidian=$PublishObsidian Teams=$PublishTeams Slack=$PublishSlack"

# -- Run engine ------------------------------------------------
try {
    $exitCode = Invoke-Engine -CliName $Cli -Binary $EngineBinary -Prompt $Prompt -LogPath $LogFile

    if ($exitCode -ne 0) {
        Write-Log "Custom brief FAILED with exit code $exitCode."
        Write-Host ""
        Write-Host "  FAILED" -ForegroundColor Red -NoNewline
        Write-Host "  Custom brief failed (exit code $exitCode)" -ForegroundColor Red
        Write-Host "  Log: $LogFile" -ForegroundColor DarkGray
        exit $exitCode
    }

    Write-Log "Custom brief complete."

    # -- Post-processing: Teams notification -------------------
    if ($Teams) {
        $teamsScript = Join-Path $ScriptDir "scripts\notify-teams.ps1"
        if ((Test-Path $teamsScript) -and $env:AI_BRIEFING_TEAMS_WEBHOOK) {
            if (Test-Path $CardFile) {
                Write-Host ""
                Write-Host "  Sending to Teams..." -ForegroundColor DarkGray
                Write-Log "Sending Teams notification..."
                try {
                    & $teamsScript -All -CardFile $CardFile
                    Write-Log "Teams notification sent."
                    Write-Host "  Teams     " -ForegroundColor Green -NoNewline
                    Write-Host "sent"
                } catch {
                    Write-Log "Teams notification failed: $_"
                    Write-Host "  Teams     " -ForegroundColor Red -NoNewline
                    Write-Host "failed"
                }
            } else {
                Write-Host "  Teams     " -ForegroundColor Yellow -NoNewline
                Write-Host "skipped " -NoNewline
                Write-Host "(no card JSON)" -ForegroundColor DarkGray
                Write-Log "Teams skipped -- card file not found."
            }
        } else {
            Write-Host "  Teams     " -ForegroundColor Yellow -NoNewline
            Write-Host "skipped " -NoNewline
            Write-Host "(webhook not set)" -ForegroundColor DarkGray
        }
    }

    # -- Post-processing: Slack notification -------------------
    if ($Slack) {
        $slackScript = Join-Path $ScriptDir "scripts\notify-slack.ps1"
        if ((Test-Path $slackScript) -and $env:AI_BRIEFING_SLACK_WEBHOOK) {
            if (Test-Path $CardFile) {
                Write-Host "  Sending to Slack..." -ForegroundColor DarkGray
                Write-Log "Sending Slack notification..."
                try {
                    & $slackScript -All -CardFile $CardFile
                    Write-Log "Slack notification sent."
                    Write-Host "  Slack     " -ForegroundColor Green -NoNewline
                    Write-Host "sent"
                } catch {
                    Write-Log "Slack notification failed: $_"
                    Write-Host "  Slack     " -ForegroundColor Red -NoNewline
                    Write-Host "failed"
                }
            } else {
                Write-Host "  Slack     " -ForegroundColor Yellow -NoNewline
                Write-Host "skipped " -NoNewline
                Write-Host "(no card JSON)" -ForegroundColor DarkGray
                Write-Log "Slack skipped -- card file not found."
            }
        } else {
            Write-Host "  Slack     " -ForegroundColor Yellow -NoNewline
            Write-Host "skipped " -NoNewline
            Write-Host "(webhook not set)" -ForegroundColor DarkGray
        }
    }

    # -- Post-processing: Obsidian publishing ---------------
    if ($Obsidian) {
        $obsidianScript = Join-Path $ScriptDir "scripts\publish-obsidian.ps1"
        $obsidianFile = Join-Path $LogDir "custom-$Timestamp-obsidian.md"
        $obsidianVault = $env:AI_BRIEFING_OBSIDIAN_VAULT
        if (-not $obsidianVault) {
            $obsidianVault = [Environment]::GetEnvironmentVariable("AI_BRIEFING_OBSIDIAN_VAULT", "User")
        }
        if ((Test-Path $obsidianScript) -and $obsidianVault) {
            if (Test-Path $obsidianFile) {
                Write-Host "  Publishing to Obsidian..." -ForegroundColor DarkGray
                Write-Log "Publishing to Obsidian vault..."
                try {
                    & $obsidianScript -File $obsidianFile
                    Write-Log "Obsidian publish complete."
                    Write-Host "  Obsidian  " -ForegroundColor Green -NoNewline
                    Write-Host "published"
                } catch {
                    Write-Log "Obsidian publish failed: $_"
                    Write-Host "  Obsidian  " -ForegroundColor Red -NoNewline
                    Write-Host "failed"
                }
            } else {
                Write-Host "  Obsidian  " -ForegroundColor Yellow -NoNewline
                Write-Host "skipped " -NoNewline
                Write-Host "(no markdown file)" -ForegroundColor DarkGray
                Write-Log "Obsidian skipped -- markdown file not found."
            }
        } else {
            Write-Host "  Obsidian  " -ForegroundColor Yellow -NoNewline
            Write-Host "skipped " -NoNewline
            Write-Host "(vault not set)" -ForegroundColor DarkGray
        }
    }
} catch {
    Write-Log "Custom brief FAILED with error: $_"
    Write-Host ""
    Write-Host "  FAILED" -ForegroundColor Red -NoNewline
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "  Done." -ForegroundColor Green -NoNewline
Write-Host "  Log: $LogFile" -ForegroundColor DarkGray
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""
