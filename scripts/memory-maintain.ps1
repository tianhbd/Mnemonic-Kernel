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
. (Join-Path $scriptDir "memory-skill-utils.ps1")

& (Join-Path $scriptDir "memory-boot.ps1") -Root $Root | Out-Null

$reviewRoot = Join-Path $Root "memory/review"
$conflictFile = Join-Path $reviewRoot "conflict-candidates.md"
$promotableFile = Join-Path $reviewRoot "promotable-memory.md"
$entries = @(Get-AllMemoryEntryRecords -Root $Root)

$conflicts = New-Object System.Collections.Generic.List[string]
$conflicts.Add("# Conflict Memory Candidates") | Out-Null
$conflicts.Add("") | Out-Null
$conflicts.Add("This conservative maintainer only reports possible conflicts; it does not auto-merge changing facts.") | Out-Null
$conflicts.Add("") | Out-Null

$sensitiveTypes = @("user_preference", "environment", "environment_fact", "project_rule", "common_path", "login_info")
$groups = $entries | Group-Object {
    "$($_.Type)|$($_.Title.ToLowerInvariant().Trim())"
} | Where-Object { $_.Count -gt 1 -and ($sensitiveTypes -contains ($_.Name -split "\|")[0]) }

if ($groups.Count -eq 0) {
    $conflicts.Add("_No conflict candidates._") | Out-Null
} else {
    foreach ($group in $groups) {
        $conflicts.Add("## $($group.Name)") | Out-Null
        foreach ($entry in $group.Group) {
            $conflicts.Add("- $($entry.Path)") | Out-Null
        }
        $conflicts.Add("") | Out-Null
    }
}

Set-Content -LiteralPath $conflictFile -Encoding UTF8 -Value ($conflicts -join "`n")

$promotable = New-Object System.Collections.Generic.List[string]
$promotable.Add("# Promotable Memory") | Out-Null
$promotable.Add("") | Out-Null
$promotable.Add("These entries meet the promotion threshold and should be reviewed before creating a skill.") | Out-Null
$promotable.Add("") | Out-Null

$priority = @{
    troubleshooting = 1
    project_rule = 2
    mechanism = 3
    common_path = 4
    environment = 5
    login_info = 6
}
$promotableEntries = @($entries | Where-Object { Test-MemoryPromotable $_ } | Sort-Object @{
    Expression = { if ($priority.ContainsKey($_.Type)) { $priority[$_.Type] } else { 99 } }
}, @{
    Expression = { -1 * $_.HitCount }
}, Title)

if ($promotableEntries.Count -eq 0) {
    $promotable.Add("_No promotable memory._") | Out-Null
} else {
    foreach ($entry in $promotableEntries) {
        $recommendation = Get-SkillRecommendationForMemory $entry
        $promotable.Add("## $($entry.Id)") | Out-Null
        $promotable.Add("- id: $($entry.Id)") | Out-Null
        $promotable.Add("- title: $($entry.Title)") | Out-Null
        $promotable.Add("- path: $($entry.Path)") | Out-Null
        $promotable.Add("- type: $($entry.Type)") | Out-Null
        $promotable.Add("- hit_count: $($entry.HitCount)") | Out-Null
        $promotable.Add("- last_hit: $($entry.LastHit)") | Out-Null
        $promotable.Add("- trigger: $($entry.Trigger -join '; ')") | Out-Null
        $promotable.Add("- summary: $($entry.Summary)") | Out-Null
        $promotable.Add("- suggested_skill_name: $($recommendation.Name)") | Out-Null
        $promotable.Add("- promotion_reason: $($recommendation.Reason)") | Out-Null
        $promotable.Add("") | Out-Null
    }
}

Set-Content -LiteralPath $promotableFile -Encoding UTF8 -Value ($promotable -join "`n")
Write-Host "Memory maintenance completed."
