param(
    [string]$Root = "",
    [datetime]$Now = (Get-Date)
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = (Resolve-Path (Join-Path $scriptDir "..")).Path
}

$memoryRoot = Join-Path $Root "memory"
$entryRoot = Join-Path $memoryRoot "entries"
$indexRoot = Join-Path $memoryRoot "index"
$requiredDirs = @(
    $entryRoot,
    $indexRoot,
    (Join-Path $memoryRoot "review"),
    (Join-Path $memoryRoot "reports")
)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

function Convert-ToRepoPath {
    param([string]$Path)
    $rootPath = (Resolve-Path -LiteralPath $Root).Path.TrimEnd("\")
    $fullPath = (Resolve-Path -LiteralPath $Path).Path
    return $fullPath.Substring($rootPath.Length + 1).Replace("\", "/")
}

function Get-ScalarField {
    param([string]$Content, [string]$Name)
    $match = [regex]::Match($Content, "(?m)^$([regex]::Escape($Name)):[^\S\r\n]*(.*)$")
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return ""
}

function Get-BlockList {
    param([string]$Content, [string]$Name)
    $items = New-Object System.Collections.Generic.List[string]
    $lines = $Content -split "\r?\n"
    $inside = $false
    foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($Name)):\s*$") {
            $inside = $true
            continue
        }
        if ($inside -and $line -match "^\w[\w_-]*:") {
            break
        }
        if ($inside -and $line -match "^\s*-\s*(.+?)\s*$") {
            $items.Add($matches[1]) | Out-Null
        }
    }
    return @($items)
}

function Get-EntryDate {
    param([string]$Value)
    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($Value, [ref]$parsed)) {
        return $parsed
    }
    return $Now
}

function New-EntryRecord {
    param([System.IO.FileInfo]$File)
    $content = Get-Content -Raw -Encoding UTF8 $File.FullName
    $titleMatch = [regex]::Match($content, "(?m)^#\s+(.+)$")
    $title = if ($titleMatch.Success) { $titleMatch.Groups[1].Value.Trim() } else { $File.BaseName }
    $created = Get-EntryDate (Get-ScalarField $content "created")
    $updated = Get-EntryDate (Get-ScalarField $content "updated")
    $hitText = Get-ScalarField $content "hit_count"
    $hitCount = 0
    [void][int]::TryParse($hitText, [ref]$hitCount)
    $type = Get-ScalarField $content "type"
    $pinned = (Get-ScalarField $content "pinned") -eq "true"
    $highValueTypes = @("user_preference", "environment", "environment_fact", "project_rule", "common_path", "login_info", "troubleshooting", "mechanism")
    $score = [Math]::Min(100, 50 + ($hitCount * 5) + $(if ($pinned) { 30 } else { 0 }) + $(if ($highValueTypes -contains $type) { 20 } else { 0 }))

    [pscustomobject]@{
        Id = Get-ScalarField $content "id"
        Title = $title
        Created = $created
        Updated = $updated
        Scope = Get-ScalarField $content "scope"
        Type = $type
        Status = Get-ScalarField $content "status"
        Risk = Get-ScalarField $content "risk"
        Pinned = $pinned
        HitCount = $hitCount
        LastHit = Get-ScalarField $content "last_hit"
        Trigger = @(Get-BlockList $content "trigger")
        Summary = Get-ScalarField $content "summary"
        Path = Convert-ToRepoPath $File.FullName
        Score = $score
    }
}

function Format-Trigger {
    param([string[]]$Items)
    $escaped = @($Items | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' })
    return "[" + ($escaped -join ", ") + "]"
}

function Format-IndexItem {
    param($Entry, [switch]$IncludeScore)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("- time: $($Entry.Updated.ToString("yyyy-MM-dd HH:mm"))") | Out-Null
    if ($IncludeScore) {
        $lines.Add("  score: $($Entry.Score)") | Out-Null
    }
    $lines.Add("  title: $($Entry.Title)") | Out-Null
    $lines.Add("  id: $($Entry.Id)") | Out-Null
    $lines.Add("  type: $($Entry.Type)") | Out-Null
    $lines.Add("  trigger: $(Format-Trigger $Entry.Trigger)") | Out-Null
    $lines.Add("  path: $($Entry.Path)") | Out-Null
    $lines.Add("  last_hit: $($Entry.LastHit)") | Out-Null
    return ($lines -join "`n")
}

function Write-IndexFile {
    param([string]$Path, [string]$Title, [object[]]$Entries, [switch]$IncludeScore)
    $body = New-Object System.Collections.Generic.List[string]
    $body.Add("# $Title") | Out-Null
    $body.Add("") | Out-Null
    $body.Add("Index files contain pointers only. Memory bodies live under memory/entries/.") | Out-Null
    $body.Add("") | Out-Null
    if ($Entries.Count -eq 0) {
        $body.Add("_No entries._") | Out-Null
    } else {
        foreach ($entry in $Entries) {
            $body.Add((Format-IndexItem $entry -IncludeScore:$IncludeScore)) | Out-Null
            $body.Add("") | Out-Null
        }
    }
    Set-Content -LiteralPath $Path -Encoding UTF8 -Value ($body -join "`n")
}

$entries = @()
if (Test-Path -LiteralPath $entryRoot) {
    $entries = @(Get-ChildItem -LiteralPath $entryRoot -Recurse -File -Filter "*.md" | ForEach-Object { New-EntryRecord $_ })
}

$entries = @($entries | Sort-Object Updated -Descending)
$recent = @($entries | Where-Object { ($Now - $_.Updated).TotalDays -le 3 })
$currentWeek = @($entries | Where-Object { ($Now - $_.Updated).TotalDays -gt 3 -and ($Now - $_.Updated).TotalDays -le 10 })
$hot = @($entries | Where-Object {
    $_.Pinned -or
    $_.HitCount -ge 5 -or
    ($_.Type -in @("user_preference", "environment", "environment_fact", "project_rule", "common_path", "login_info", "troubleshooting", "mechanism"))
} | Sort-Object Score, Updated -Descending)

$defaultBody = @"
# Default Memory Index

Index files contain pointers only. Memory bodies live under memory/entries/.

## recent-3d

$(
if ($recent.Count -eq 0) { "_No entries._" } else { ($recent | ForEach-Object { Format-IndexItem $_ }) -join "`n`n" }
)

## hot

$(
if ($hot.Count -eq 0) { "_No entries._" } else { ($hot | ForEach-Object { Format-IndexItem $_ -IncludeScore }) -join "`n`n" }
)
"@

Set-Content -LiteralPath (Join-Path $indexRoot "default.md") -Encoding UTF8 -Value $defaultBody
Write-IndexFile (Join-Path $indexRoot "current-week.md") "Current Week Memory Index" $currentWeek

$monthEntries = @($entries | Where-Object { ($Now - $_.Updated).TotalDays -gt 10 -and ($Now - $_.Updated).TotalDays -le 183 })
$monthGroups = $monthEntries | Group-Object { $_.Updated.ToString("yyyy-MM") }
foreach ($group in $monthGroups) {
    Write-IndexFile (Join-Path $indexRoot "month-$($group.Name).md") "Month $($group.Name) Memory Index" @($group.Group)
}
if (-not (Test-Path -LiteralPath (Join-Path $indexRoot "month-$($Now.ToString("yyyy-MM")).md"))) {
    Write-IndexFile (Join-Path $indexRoot "month-$($Now.ToString("yyyy-MM")).md") "Month $($Now.ToString("yyyy-MM")) Memory Index" @()
}

$yearEntries = @($entries | Where-Object { ($Now - $_.Updated).TotalDays -gt 183 })
$yearGroups = $yearEntries | Group-Object { $_.Updated.ToString("yyyy") }
foreach ($group in $yearGroups) {
    Write-IndexFile (Join-Path $indexRoot "year-$($group.Name).md") "Year $($group.Name) Memory Index" @($group.Group)
}
if (-not (Test-Path -LiteralPath (Join-Path $indexRoot "year-$($Now.ToString("yyyy")).md"))) {
    Write-IndexFile (Join-Path $indexRoot "year-$($Now.ToString("yyyy")).md") "Year $($Now.ToString("yyyy")) Memory Index" @()
}

$cold = @($entries | Where-Object { $_.Status -eq "cold" -or (($_.HitCount -eq 0) -and (($Now - $_.Updated).TotalDays -gt 365)) })
Write-IndexFile (Join-Path $indexRoot "cold.md") "Cold Memory Index" $cold

$masterLines = New-Object System.Collections.Generic.List[string]
$masterLines.Add("# Memory Master Index") | Out-Null
$masterLines.Add("") | Out-Null
$masterLines.Add("- Default: memory/index/default.md") | Out-Null
$masterLines.Add("- Current week: memory/index/current-week.md") | Out-Null
Get-ChildItem -LiteralPath $indexRoot -File -Filter "month-*.md" | Sort-Object Name -Descending | ForEach-Object {
    $masterLines.Add("- Month: $(Convert-ToRepoPath $_.FullName)") | Out-Null
}
Get-ChildItem -LiteralPath $indexRoot -File -Filter "year-*.md" | Sort-Object Name -Descending | ForEach-Object {
    $masterLines.Add("- Year: $(Convert-ToRepoPath $_.FullName)") | Out-Null
}
$masterLines.Add("- Cold: memory/index/cold.md") | Out-Null
Set-Content -LiteralPath (Join-Path $indexRoot "master.md") -Encoding UTF8 -Value ($masterLines -join "`n")

Write-Host "Memory indexes rebuilt: $($entries.Count) entries."
