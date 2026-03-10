#Requires -Version 5.1
Set-StrictMode -Version Latest

# topic-edit.ps1 — List, add, or remove topics from prompt.md on Windows.
# Usage:
#   .\scripts\topic-edit.ps1 -Action list
#   .\scripts\topic-edit.ps1 -Action add -Name "AI Hardware" -Description "GPU releases, chip news"
#   .\scripts\topic-edit.ps1 -Action remove -Number 9

param(
    [Parameter(Mandatory)]
    [ValidateSet("list","add","remove")]
    [string]$Action,

    [string]$Name = "",
    [string]$Description = "",
    [int]$Number = 0
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$PromptPath = Join-Path $ScriptDir "prompt.md"

function Get-Topics {
    $lines = Get-Content $PromptPath
    $topics = @()
    foreach ($line in $lines) {
        if ($line -match '^\d+\.\s+\*\*') {
            $topics += $line
        }
    }
    return $topics
}

function Show-Topics {
    Write-Host ""
    Write-Host "  Current Topics in prompt.md" -ForegroundColor White
    Write-Host "  ==========================="
    Write-Host ""

    $topics = Get-Topics
    foreach ($t in $topics) {
        if ($t -match '^(\d+)\.\s+\*\*(.+?)\*\*\s*.*?([^*]+)$') {
            $num = $Matches[1]
            $rawName = $Matches[2]
            $desc = $t -replace '^.*?—\s*', ''
            Write-Host ("  {0,2}. {1,-30} " -f $num, $rawName) -NoNewline
            Write-Host $desc -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  Total: $($topics.Count) topics"
    Write-Host "  Notion 'Topics' property should be: $($topics.Count)"
    Write-Host ""
}

switch ($Action) {
    "list" {
        Show-Topics
    }

    "add" {
        if (-not $Name) {
            Write-Host "Usage: topic-edit.ps1 -Action add -Name `"Topic Name`" -Description `"what to cover`""
            exit 1
        }

        # Auto-backup
        $backupScript = Join-Path $ScriptDir "scripts\backup-prompt.ps1"
        if (Test-Path $backupScript) {
            & $backupScript -Action backup 2>$null
        }

        $lines = Get-Content $PromptPath
        $topics = Get-Topics
        $currentMax = $topics.Count
        $nextNum = $currentMax + 1

        # Find last topic line index
        $lastTopicIdx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\d+\.\s+\*\*') {
                $lastTopicIdx = $i
            }
        }

        $newLine = "$nextNum. **$Name** --- $Description"
        $newLines = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $newLines += $lines[$i]
            if ($i -eq $lastTopicIdx) {
                $newLines += $newLine
            }
        }

        # Update Topics count
        $newLines = $newLines | ForEach-Object {
            $_ -replace '"Topics":\s*\d+', "`"Topics`": $nextNum"
        }

        Set-Content -Path $PromptPath -Value $newLines -Encoding UTF8

        Write-Host ""
        Write-Host "  Added topic #${nextNum}: $Name" -ForegroundColor Green
        Write-Host "  Updated Notion 'Topics' property to $nextNum"
        Write-Host ""
        Show-Topics
    }

    "remove" {
        if ($Number -eq 0) {
            Write-Host "Usage: topic-edit.ps1 -Action remove -Number N"
            exit 1
        }

        # Auto-backup
        $backupScript = Join-Path $ScriptDir "scripts\backup-prompt.ps1"
        if (Test-Path $backupScript) {
            & $backupScript -Action backup 2>$null
        }

        $lines = Get-Content $PromptPath
        $removed = $false
        $newLines = @()

        foreach ($line in $lines) {
            if ($line -match "^${Number}\.\s+" -and -not $removed) {
                Write-Host "  Removed: $line" -ForegroundColor Yellow
                $removed = $true
                continue
            }
            $newLines += $line
        }

        if (-not $removed) {
            Write-Host "Topic #$Number not found."
            exit 1
        }

        $newCount = ($newLines | Where-Object { $_ -match '^\d+\.\s+\*\*' }).Count

        $newLines = $newLines | ForEach-Object {
            $_ -replace '"Topics":\s*\d+', "`"Topics`": $newCount"
        }

        Set-Content -Path $PromptPath -Value $newLines -Encoding UTF8

        Write-Host "  Updated Notion 'Topics' property to $newCount"
        Write-Host "  (Note: topic numbers may need manual renumbering)"
        Write-Host ""
        Show-Topics
    }
}
