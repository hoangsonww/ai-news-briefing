#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# dry-run.ps1 — Test the briefing pipeline without writing to Notion.
# Runs Claude with a modified prompt that skips the Notion write step.
# Usage: .\scripts\dry-run.ps1 [-Model sonnet] [-Budget 1.00]

param(
    [ValidateSet("haiku","sonnet","opus")]
    [string]$Model = "sonnet",
    [decimal]$Budget = 1.00
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
$Date = Get-Date -Format "yyyy-MM-dd"
$Time = Get-Date -Format "HH:mm:ss"
$LogDir = Join-Path $ScriptDir "logs"
$LogFile = Join-Path $LogDir "$Date-dry-run.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "$Date $ts $Message"
    Write-Host $line
    $line | Out-File -FilePath $LogFile -Append -Encoding utf8
}

Write-Log "Starting DRY RUN (model=$Model, budget=$Budget)..."
Write-Log "  This will search and compile but NOT write to Notion."
Write-Log ""

# Read and modify the prompt to skip Notion write
$Prompt = Get-Content -Path (Join-Path $ScriptDir "prompt.md") -Raw

# Replace Step 3 with a stdout instruction
$DryPrompt = $Prompt -replace `
    '(?s)## Step 3: Write to Notion.*?(?=## Important Notes)', `
    @"
## Step 3: Output the Briefing

Do NOT write to Notion. Instead, print the full compiled briefing to stdout.
Format it exactly as you would for Notion (Markdown with ## headings, - bullets, **bold**).
This is a dry run for testing purposes.

"@

$env:CLAUDECODE = $null

try {
    $output = & $Claude -p `
        --model $Model `
        --dangerously-skip-permissions `
        --max-budget-usd $Budget `
        $DryPrompt 2>&1

    $output | Tee-Object -Variable result | Out-File -FilePath $LogFile -Append -Encoding utf8
    $output | Write-Host

    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        Write-Log ""
        Write-Log "Dry run complete. Output above and in: $LogFile"
    } else {
        Write-Log ""
        Write-Log "Dry run FAILED with exit code $exitCode."
    }
} catch {
    Write-Log "Dry run FAILED with error: $_"
}
