#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# publish-obsidian.ps1 — Publish a briefing markdown file to an Obsidian vault.
# Creates topic stub pages for graph visualization if they don't already exist.
#
# Usage:
#   .\scripts\publish-obsidian.ps1 -File logs\2026-04-11-obsidian.md
#
# Requires: AI_BRIEFING_OBSIDIAN_VAULT environment variable set to the vault path.

param(
    [Parameter(Mandatory=$true)]
    [string]$File
)

# -- Validate inputs ---------------------------------------
if (-not (Test-Path $File)) {
    Write-Host "  ERROR  Source file not found: $File" -ForegroundColor Red
    exit 1
}

$Vault = $env:AI_BRIEFING_OBSIDIAN_VAULT
if (-not $Vault) {
    # Check user-level env var
    $Vault = [Environment]::GetEnvironmentVariable("AI_BRIEFING_OBSIDIAN_VAULT", "User")
}

if (-not $Vault) {
    Write-Host "  ERROR  AI_BRIEFING_OBSIDIAN_VAULT is not set" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Vault -PathType Container)) {
    Write-Host "  ERROR  Vault directory not found: $Vault" -ForegroundColor Red
    exit 1
}

# -- Ensure vault subdirectories exist ---------------------
$BriefingsDir = Join-Path $Vault "AI-News-Briefings"
$TopicsDir = Join-Path $Vault "Topics"
New-Item -ItemType Directory -Path $BriefingsDir -Force | Out-Null
New-Item -ItemType Directory -Path $TopicsDir -Force | Out-Null

# -- Copy briefing to vault --------------------------------
$FileName = (Split-Path $File -Leaf) -replace '-obsidian\.md$', '.md'
$DestFile = Join-Path $BriefingsDir $FileName

Copy-Item -Path $File -Destination $DestFile -Force
Write-Host "  Published  " -ForegroundColor Green -NoNewline
Write-Host "$DestFile"

# -- Create topic stub pages for graph nodes ---------------
$content = Get-Content -Path $File -Raw
$topics = [regex]::Matches($content, '\[\[([^\]]+)\]\]') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

$created = 0
$existing = 0

foreach ($topic in $topics) {
    if (-not $topic) { continue }
    $topicFile = Join-Path $TopicsDir "$topic.md"

    if (-not (Test-Path $topicFile)) {
        $date = Get-Date -Format "yyyy-MM-dd"
        $stub = @"
---
type: topic
created: $date
---

# $topic

This is a topic hub for **$topic** in the AI News Briefing system.

Briefings mentioning this topic are automatically linked via Obsidian's backlinks panel and graph view.

## See Also

Check the **Backlinks** panel (or graph view) to see all briefings referencing this topic.
"@
        $stub | Out-File -FilePath $topicFile -Encoding utf8
        $created++
    } else {
        $existing++
    }
}

if ($created -gt 0) {
    Write-Host "  Topics     " -ForegroundColor Green -NoNewline
    Write-Host "$created new topic page(s) created, $existing already existed"
} else {
    Write-Host "  Topics     " -ForegroundColor DarkGray -NoNewline
    Write-Host "all $existing topic pages already exist"
}

Write-Host "  Graph      " -ForegroundColor DarkGray -NoNewline
Write-Host "open Obsidian and check the graph view to see topic connections"
