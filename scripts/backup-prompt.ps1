#Requires -Version 5.1
Set-StrictMode -Version Latest

# backup-prompt.ps1 — Version and backup prompt.md before making changes.
# Usage:
#   .\scripts\backup-prompt.ps1                  # Backup current prompt
#   .\scripts\backup-prompt.ps1 -Action list     # List all backups
#   .\scripts\backup-prompt.ps1 -Action restore -Index 1  # Restore backup #1
#   .\scripts\backup-prompt.ps1 -Action diff -Index 1     # Diff backup #1 vs current

param(
    [ValidateSet("backup","list","restore","diff")]
    [string]$Action = "backup",
    [int]$Index = 0
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$PromptPath = Join-Path $ScriptDir "prompt.md"
$BackupDir = Join-Path $ScriptDir "backups"

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

function Get-Backups {
    Get-ChildItem -Path $BackupDir -Filter "prompt-*.md" -File |
        Sort-Object LastWriteTime -Descending
}

function Get-BackupByIndex {
    param([int]$Idx)
    $backups = @(Get-Backups)
    if ($Idx -lt 1 -or $Idx -gt $backups.Count) { return $null }
    return $backups[$Idx - 1]
}

switch ($Action) {
    "backup" {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $dest = Join-Path $BackupDir "prompt-$timestamp.md"
        Copy-Item $PromptPath $dest
        Write-Host ""
        Write-Host "  Backed up prompt.md to:"
        Write-Host "  $dest"
        Write-Host ""

        # Keep only last 20
        $backups = @(Get-Backups)
        if ($backups.Count -gt 20) {
            $backups[20..($backups.Count - 1)] | Remove-Item -Force
            Write-Host "  (Pruned old backups, keeping latest 20)"
            Write-Host ""
        }
    }

    "list" {
        Write-Host ""
        Write-Host "  Prompt Backups" -ForegroundColor White
        Write-Host "  =============="
        Write-Host ""
        $backups = @(Get-Backups)
        if ($backups.Count -eq 0) {
            Write-Host "  No backups found."
        } else {
            $i = 1
            foreach ($b in $backups) {
                $sizeKB = [math]::Round($b.Length / 1024, 1)
                Write-Host ("  {0,2}. {1,-40} {2:N1} KB" -f $i, $b.Name, $sizeKB)
                $i++
            }
        }
        Write-Host ""
    }

    "restore" {
        if ($Index -eq 0) {
            Write-Host "Usage: backup-prompt.ps1 -Action restore -Index N"
            Write-Host "Run with -Action list to see available backups."
            exit 1
        }
        $file = Get-BackupByIndex $Index
        if (-not $file) {
            Write-Host "Backup #$Index not found. Run -Action list to see available backups."
            exit 1
        }
        # Backup current before restoring
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $preRestore = Join-Path $BackupDir "prompt-$timestamp-pre-restore.md"
        Copy-Item $PromptPath $preRestore
        Copy-Item $file.FullName $PromptPath
        Write-Host ""
        Write-Host "  Restored prompt.md from: $($file.Name)"
        Write-Host "  (Previous version backed up as: $(Split-Path $preRestore -Leaf))"
        Write-Host ""
    }

    "diff" {
        if ($Index -eq 0) {
            Write-Host "Usage: backup-prompt.ps1 -Action diff -Index N"
            exit 1
        }
        $file = Get-BackupByIndex $Index
        if (-not $file) {
            Write-Host "Backup #$Index not found."
            exit 1
        }
        Write-Host ""
        Write-Host "  Diff: $($file.Name) vs current prompt.md" -ForegroundColor White
        Write-Host "  ================================================"
        Write-Host ""

        $old = Get-Content $file.FullName
        $new = Get-Content $PromptPath
        $diff = Compare-Object $old $new -IncludeEqual

        foreach ($line in $diff) {
            switch ($line.SideIndicator) {
                "==" { Write-Host "  $($line.InputObject)" }
                "<=" { Write-Host "- $($line.InputObject)" -ForegroundColor Red }
                "=>" { Write-Host "+ $($line.InputObject)" -ForegroundColor Green }
            }
        }
        Write-Host ""
    }
}
