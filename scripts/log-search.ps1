#Requires -Version 5.1
Set-StrictMode -Version Latest

# log-search.ps1 — Search across all logs for a keyword or pattern.
# Usage:
#   .\scripts\log-search.ps1 -Pattern "Anthropic"
#   .\scripts\log-search.ps1 -Pattern "FAILED" -CountOnly
#   .\scripts\log-search.ps1 -Pattern "OpenAI" -Context 3

param(
    [Parameter(Mandatory)]
    [string]$Pattern,
    [switch]$CountOnly,
    [int]$Context = 1
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$LogDir = Join-Path $ScriptDir "logs"

if (-not (Test-Path $LogDir)) {
    Write-Host "No logs directory found."
    exit 0
}

Write-Host ""
Write-Host "  Searching logs for: `"$Pattern`"" -ForegroundColor White
Write-Host "  ================================"
Write-Host ""

$logs = Get-ChildItem -Path $LogDir -Filter "*.log" -File | Sort-Object Name -Descending

if ($CountOnly) {
    $totalMatches = 0
    foreach ($log in $logs) {
        $matches = (Select-String -Path $log.FullName -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue).Count
        if ($matches -gt 0) {
            Write-Host ("  {0,-24} {1} matches" -f $log.Name, $matches)
            $totalMatches += $matches
        }
    }
    Write-Host ""
    Write-Host "  Total: $totalMatches matches across all logs"
} else {
    $found = $false
    foreach ($log in $logs) {
        $results = Select-String -Path $log.FullName -Pattern $Pattern -Context $Context, $Context -ErrorAction SilentlyContinue
        if ($results) {
            $found = $true
            foreach ($r in $results) {
                Write-Host "$($log.Name):$($r.LineNumber):" -ForegroundColor Cyan -NoNewline

                # Context before
                if ($r.Context.PreContext) {
                    foreach ($pre in $r.Context.PreContext) {
                        Write-Host "  $pre" -ForegroundColor DarkGray
                    }
                }

                # Matching line
                Write-Host "  $($r.Line)" -ForegroundColor Yellow

                # Context after
                if ($r.Context.PostContext) {
                    foreach ($post in $r.Context.PostContext) {
                        Write-Host "  $post" -ForegroundColor DarkGray
                    }
                }
                Write-Host ""
            }
        }
    }
    if (-not $found) {
        Write-Host "  No matches found."
    }
}
Write-Host ""
