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

& (Join-Path $scriptDir "memory-boot.ps1") -Root $Root | Out-Null

$reviewRoot = Join-Path $Root "memory/review"
$conflictFile = Join-Path $reviewRoot "conflict-candidates.md"
$entries = @(Get-ChildItem -LiteralPath (Join-Path $Root "memory/entries") -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue)

$conflicts = New-Object System.Collections.Generic.List[string]
$conflicts.Add("# Conflict Memory Candidates") | Out-Null
$conflicts.Add("") | Out-Null
$conflicts.Add("This conservative maintainer only reports possible conflicts; it does not auto-merge changing facts.") | Out-Null
$conflicts.Add("") | Out-Null

$sensitiveTypes = @("user_preference", "environment", "environment_fact", "project_rule", "common_path", "login_info")
$groups = $entries | Group-Object {
    $content = Get-Content -Raw -Encoding UTF8 $_.FullName
    $type = if ($content -match "(?m)^type:\s*(.+)$") { $matches[1].Trim() } else { "" }
    $title = if ($content -match "(?m)^#\s+(.+)$") { $matches[1].ToLowerInvariant().Trim() } else { $_.BaseName.ToLowerInvariant() }
    "$type|$title"
} | Where-Object { $_.Count -gt 1 -and ($sensitiveTypes -contains ($_.Name -split "\|")[0]) }

if ($groups.Count -eq 0) {
    $conflicts.Add("_No conflict candidates._") | Out-Null
} else {
    foreach ($group in $groups) {
        $conflicts.Add("## $($group.Name)") | Out-Null
        foreach ($file in $group.Group) {
            $conflicts.Add("- $($file.FullName.Substring($Root.Length + 1).Replace('\', '/'))") | Out-Null
        }
        $conflicts.Add("") | Out-Null
    }
}

Set-Content -LiteralPath $conflictFile -Encoding UTF8 -Value ($conflicts -join "`n")
Write-Host "Memory maintenance completed."
