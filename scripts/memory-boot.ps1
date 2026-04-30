param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = (Resolve-Path (Join-Path $scriptDir "..")).Path
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$memoryRoot = Join-Path $Root "memory"
$indexRoot = Join-Path $memoryRoot "index"
$reportRoot = Join-Path $memoryRoot "reports"
$reviewRoot = Join-Path $memoryRoot "review"
$archiveRoot = Join-Path $memoryRoot "archive"

foreach ($dir in @($indexRoot, $reportRoot, $reviewRoot, $archiveRoot)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

function Convert-ToFullPath {
    param([string]$RepoPath)
    return Join-Path $Root ($RepoPath -replace "/", "\")
}

function Get-IndexPaths {
    param([string]$IndexFile)
    if (-not (Test-Path -LiteralPath $IndexFile)) {
        return @()
    }
    $content = Get-Content -Raw -Encoding UTF8 $IndexFile
    return @([regex]::Matches($content, "(?m)^\s*path:\s*(memory/entries/.+?\.md)\s*$") | ForEach-Object { $_.Groups[1].Value })
}

$removed = New-Object System.Collections.Generic.List[string]
if (Test-Path -LiteralPath $indexRoot) {
    foreach ($indexFile in Get-ChildItem -LiteralPath $indexRoot -File -Filter "*.md") {
        $content = Get-Content -Raw -Encoding UTF8 $indexFile.FullName
        $paths = Get-IndexPaths $indexFile.FullName
        foreach ($path in $paths) {
            if (-not (Test-Path -LiteralPath (Convert-ToFullPath $path))) {
                $removed.Add("$($indexFile.Name): $path") | Out-Null
                $content = [regex]::Replace($content, "(?ms)^- time:.*?^\s*path:\s*$([regex]::Escape($path)).*?(?=^- time:|\z)", "")
            }
        }
        Set-Content -LiteralPath $indexFile.FullName -Encoding UTF8 -Value $content
    }
}

& (Join-Path $scriptDir "memory-index.ps1") -Root $Root | Out-Null

$entries = @()
$entryRoot = Join-Path $memoryRoot "entries"
if (Test-Path -LiteralPath $entryRoot) {
    $entries = @(Get-ChildItem -LiteralPath $entryRoot -Recurse -File -Filter "*.md")
}

$duplicateGroups = $entries | Group-Object {
    $content = Get-Content -Raw -Encoding UTF8 $_.FullName
    $title = if ($content -match "(?m)^#\s+(.+)$") { $matches[1].ToLowerInvariant().Trim() } else { $_.BaseName.ToLowerInvariant() }
    $type = if ($content -match "(?m)^type:\s*(.+)$") { $matches[1].Trim() } else { "" }
    $scope = if ($content -match "(?m)^scope:\s*(.+)$") { $matches[1].Trim() } else { "" }
    "$title|$type|$scope"
} | Where-Object { $_.Count -gt 1 }

$duplicateReport = New-Object System.Collections.Generic.List[string]
$duplicateReport.Add("# Duplicate Memory Candidates") | Out-Null
$duplicateReport.Add("") | Out-Null
if ($duplicateGroups.Count -eq 0) {
    $duplicateReport.Add("_No duplicate candidates._") | Out-Null
} else {
    foreach ($group in $duplicateGroups) {
        $duplicateReport.Add("## $($group.Name)") | Out-Null
        foreach ($file in $group.Group) {
            $duplicateReport.Add("- $($file.FullName.Substring($Root.Length + 1).Replace('\', '/'))") | Out-Null
        }
        $duplicateReport.Add("") | Out-Null
    }
}
Set-Content -LiteralPath (Join-Path $reviewRoot "duplicate-candidates.md") -Encoding UTF8 -Value ($duplicateReport -join "`n")

$report = New-Object System.Collections.Generic.List[string]
$report.Add("# Memory Boot Report") | Out-Null
$report.Add("") | Out-Null
$report.Add("- time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")") | Out-Null
$report.Add("- entries: $($entries.Count)") | Out-Null
$report.Add("- invalid_pointers_removed: $($removed.Count)") | Out-Null
$report.Add("- duplicate_candidate_groups: $($duplicateGroups.Count)") | Out-Null
$report.Add("") | Out-Null
$report.Add("## Removed Invalid Pointers") | Out-Null
$report.Add("") | Out-Null
if ($removed.Count -eq 0) {
    $report.Add("_None._") | Out-Null
} else {
    $removed | ForEach-Object { $report.Add("- $_") | Out-Null }
}
Set-Content -LiteralPath (Join-Path $reportRoot "boot-report.md") -Encoding UTF8 -Value ($report -join "`n")

Write-Host "Memory boot completed. Report: memory/reports/boot-report.md"
