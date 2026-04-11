#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# test-obsidian.ps1 — Test Obsidian vault connectivity on Windows.
# Verifies that the vault directory exists and is writable.
# Usage: .\scripts\test-obsidian.ps1

Write-Host ""
Write-Host "  AI News Briefing - Obsidian Vault Connectivity Test" -ForegroundColor White
Write-Host "  ===================================================="
Write-Host ""

$Vault = $env:AI_BRIEFING_OBSIDIAN_VAULT
if (-not $Vault) {
    $Vault = [Environment]::GetEnvironmentVariable("AI_BRIEFING_OBSIDIAN_VAULT", "User")
}

if (-not $Vault) {
    Write-Host "  FAIL  AI_BRIEFING_OBSIDIAN_VAULT is not set." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Set it to your Obsidian vault path:"
    Write-Host '    [Environment]::SetEnvironmentVariable("AI_BRIEFING_OBSIDIAN_VAULT", "C:\path\to\vault", "User")'
    Write-Host ""
    exit 1
}

Write-Host "  Vault path: $Vault"

if (-not (Test-Path $Vault -PathType Container)) {
    Write-Host "  FAIL  Directory does not exist: $Vault" -ForegroundColor Red
    exit 1
}
Write-Host "  Directory:  exists" -ForegroundColor Green

# Check if writable
try {
    $testFile = Join-Path $Vault ".ai-briefing-write-test"
    "" | Out-File -FilePath $testFile -Encoding utf8
    Remove-Item $testFile -Force
    Write-Host "  Writable:   yes" -ForegroundColor Green
} catch {
    Write-Host "  FAIL  Directory is not writable: $Vault" -ForegroundColor Red
    exit 1
}

# Check if it looks like an Obsidian vault
$obsidianDir = Join-Path $Vault ".obsidian"
if (Test-Path $obsidianDir -PathType Container) {
    Write-Host "  Obsidian:   .obsidian config found (confirmed vault)" -ForegroundColor Green
} else {
    Write-Host "  Obsidian:   no .obsidian config (directory will work but may not be initialized as a vault)" -ForegroundColor Yellow
}

# Check subdirectories
$briefingsDir = Join-Path $Vault "AI-News-Briefings"
$topicsDir = Join-Path $Vault "Topics"

if (Test-Path $briefingsDir -PathType Container) {
    $count = (Get-ChildItem -Path $briefingsDir -Filter "*.md" -File).Count
    Write-Host "  Briefings:  $count file(s) in AI-News-Briefings/"
} else {
    Write-Host "  Briefings:  AI-News-Briefings/ will be created on first publish" -ForegroundColor DarkGray
}

if (Test-Path $topicsDir -PathType Container) {
    $count = (Get-ChildItem -Path $topicsDir -Filter "*.md" -File).Count
    Write-Host "  Topics:     $count topic page(s) in Topics/"
} else {
    Write-Host "  Topics:     Topics/ will be created on first publish" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Test complete. Obsidian vault is ready." -ForegroundColor Green
Write-Host ""
