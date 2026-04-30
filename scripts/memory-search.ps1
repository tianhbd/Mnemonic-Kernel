param(
    [Parameter(Mandatory = $true)][string]$Query,
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = (Resolve-Path (Join-Path $scriptDir "..")).Path
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$indexRoot = Join-Path $Root "memory/index"
$queryTerms = @($Query.ToLowerInvariant() -split "\s+" | Where-Object { $_ })

function Get-SearchOrder {
    $files = New-Object System.Collections.Generic.List[string]
    $files.Add((Join-Path $indexRoot "default.md")) | Out-Null
    $files.Add((Join-Path $indexRoot "current-week.md")) | Out-Null
    Get-ChildItem -LiteralPath $indexRoot -File -Filter "month-*.md" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 6 | ForEach-Object {
        $files.Add($_.FullName) | Out-Null
    }
    Get-ChildItem -LiteralPath $indexRoot -File -Filter "year-*.md" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object {
        $files.Add($_.FullName) | Out-Null
    }
    $files.Add((Join-Path $indexRoot "cold.md")) | Out-Null
    return @($files | Where-Object { Test-Path -LiteralPath $_ })
}

function Convert-ToFullPath {
    param([string]$RepoPath)
    return Join-Path $Root ($RepoPath -replace "/", "\")
}

function Get-MatchingPaths {
    param([string]$IndexFile)
    $content = Get-Content -Raw -Encoding UTF8 $IndexFile
    $blocks = [regex]::Matches($content, "(?ms)^- time:.*?(?=^- time:|\z)")
    foreach ($block in $blocks) {
        $text = $block.Value.ToLowerInvariant()
        $matchesAll = $true
        foreach ($term in $queryTerms) {
            if ($text -notlike "*$term*") {
                $matchesAll = $false
                break
            }
        }
        if ($matchesAll -and $block.Value -match "(?m)^\s*path:\s*(memory/entries/.+?\.md)\s*$") {
            [pscustomobject]@{
                Index = $IndexFile
                Path = $matches[1]
            }
        }
    }
}

function Update-HitStats {
    param([string]$EntryFile)
    $content = Get-Content -Raw -Encoding UTF8 $EntryFile
    $hit = 0
    if ($content -match "(?m)^hit_count:[^\S\r\n]*(\d+)[^\S\r\n]*$") {
        $hit = [int]$matches[1]
        $content = [regex]::Replace($content, "(?m)^hit_count:[^\S\r\n]*\d+[^\S\r\n]*$", "hit_count: $($hit + 1)")
    } else {
        $content = [regex]::Replace($content, "(?m)^(pinned:\s*.*)$", "`$1`nhit_count: 1")
    }
    $today = Get-Date -Format "yyyy-MM-dd"
    if ($content -match "(?m)^last_hit:[^\S\r\n]*[^\r\n]*$") {
        $content = [regex]::Replace($content, "(?m)^last_hit:[^\S\r\n]*[^\r\n]*$", "last_hit: $today")
    } else {
        $content = [regex]::Replace($content, "(?m)^(hit_count:\s*.*)$", "`$1`nlast_hit: $today")
    }
    Set-Content -LiteralPath $EntryFile -Encoding UTF8 -Value $content
}

foreach ($index in Get-SearchOrder) {
    $matches = @(Get-MatchingPaths $index)
    if ($matches.Count -gt 0) {
        $match = $matches[0]
        $entryFile = Convert-ToFullPath $match.Path
        if (-not (Test-Path -LiteralPath $entryFile)) {
            continue
        }
        Update-HitStats $entryFile
        & (Join-Path $scriptDir "memory-index.ps1") -Root $Root | Out-Null
        Write-Host "Matched index: $($match.Index.Substring($Root.Length + 1).Replace('\', '/'))"
        Write-Host "Matched entry: $($match.Path)"
        Get-Content -Raw -Encoding UTF8 $entryFile
        exit 0
    }
}

Write-Host "No memory match found for query: $Query"
exit 1
