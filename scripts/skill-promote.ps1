param(
    [string]$Root = "",
    [int]$HitThreshold = 5,
    [string]$MemoryId = "",
    [switch]$Confirmed,
    [string]$Scope = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = (Resolve-Path (Join-Path $scriptDir "..")).Path
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
. (Join-Path $scriptDir "memory-skill-utils.ps1")

if (-not [string]::IsNullOrWhiteSpace($Scope) -and $Scope -notin @("project", "global")) {
    throw "Invalid scope value: $Scope. Must be 'project' or 'global'."
}

$reviewRoot = Join-Path $Root "memory/review"
$reportRoot = Join-Path $Root "memory/reports"
$candidateFile = Join-Path $reviewRoot "skill-promote-candidates.md"
$promotionReport = Join-Path $reportRoot "promoted-memory.md"

foreach ($dir in @($reviewRoot, $reportRoot)) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

function Write-CandidateFile {
    param([object[]]$Entries)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Skill Promotion Candidates") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("These candidates are suggestions only. Use `skill-promote.ps1 -Confirmed -MemoryId <id>` to promote a single entry.") | Out-Null
    $lines.Add("") | Out-Null

    if ($Entries.Count -eq 0) {
        $lines.Add("_No skill promotion candidates._") | Out-Null
    } else {
        foreach ($entry in $Entries) {
            $recommendation = Get-SkillRecommendationForMemory $entry
            $lines.Add("## $($entry.Id)") | Out-Null
            $lines.Add("- memory_id: $($entry.Id)") | Out-Null
            $lines.Add("- title: $($entry.Title)") | Out-Null
            $lines.Add("- path: $($entry.Path)") | Out-Null
            $lines.Add("- type: $($entry.Type)") | Out-Null
            $lines.Add("- hit_count: $($entry.HitCount)") | Out-Null
            $lines.Add("- last_hit: $($entry.LastHit)") | Out-Null
            $lines.Add("- trigger: $($entry.Trigger -join '; ')") | Out-Null
            $lines.Add("- summary: $($entry.Summary)") | Out-Null
            $lines.Add("- recommended_skill_name: $($recommendation.Name)") | Out-Null
            $lines.Add("- recommended_skill_slug: $($recommendation.Slug)") | Out-Null
            $lines.Add("- recommended_triggers: $($recommendation.Triggers -join '; ')") | Out-Null
            $lines.Add("- recommended_workflow: $($recommendation.Workflow -replace '\r?\n', ' / ')") | Out-Null
            $lines.Add("- recommended_verification: $($recommendation.Verification)") | Out-Null
            $lines.Add("- promotion_reason: $($recommendation.Reason)") | Out-Null
            $lines.Add("") | Out-Null
        }
    }

    Set-Content -LiteralPath $candidateFile -Encoding UTF8 -Value ($lines -join "`n")
}

$entries = @(Get-AllMemoryEntryRecords -Root $Root | Where-Object { Test-MemoryPromotable $_ -HitThreshold $HitThreshold } | Sort-Object Title | Sort-Object HitCount -Descending)
Write-CandidateFile $entries

if (-not $Confirmed) {
    Write-Host "Generated $((Convert-ToRepoPath -Path $candidateFile -Root $Root))"
    return
}

if ([string]::IsNullOrWhiteSpace($MemoryId)) {
    throw "MemoryId is required when using -Confirmed."
}

$entry = $entries | Where-Object { $_.Id -eq $MemoryId } | Select-Object -First 1
if ($null -eq $entry) {
    throw "Promotable memory not found for id: $MemoryId"
}

$recommendation = Get-SkillRecommendationForMemory $entry
$promotedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm")
& (Join-Path $scriptDir "new-skill.ps1") `
    -Name $recommendation.Name `
    -Description $entry.Summary `
    -Trigger $recommendation.Triggers[0] `
    -Triggers $recommendation.Triggers `
    -Workflow $recommendation.Workflow `
    -Verification $recommendation.Verification `
    -Slug $recommendation.Slug `
    -Category $recommendation.Category `
    -Toolsets @("terminal") `
    -PromotedFromMemoryId $entry.Id `
    -PromotedFromMemoryPath $entry.Path `
    -PromotedFromMemoryHitCount $entry.HitCount `
    -PromotedAt $promotedAt `
    -Scope $(if (-not [string]::IsNullOrWhiteSpace($Scope)) { $Scope } elseif (-not [string]::IsNullOrWhiteSpace($entry.Scope)) { $entry.Scope } else { "project" }) `
    -ScopeOverridden $(((-not [string]::IsNullOrWhiteSpace($Scope)) -and ($Scope -ne $entry.Scope)).ToString().ToLowerInvariant()) `
    -OverriddenTo $(if (($Scope -ne $entry.Scope) -and (-not [string]::IsNullOrWhiteSpace($Scope))) { $Scope } else { "" }) `
    -Confirmed `
    -Root $Root | Out-Null

Remove-Item -LiteralPath $entry.FullPath -Force
& (Join-Path $scriptDir "memory-index.ps1") -Root $Root | Out-Null

$skillPath = "skills/$($recommendation.Slug)/SKILL.md"
$report = @"
# Promoted Memory Report

time: $promotedAt
memory_id: $($entry.Id)
memory_path: $($entry.Path)
deleted_memory: true
skill_name: $($recommendation.Name)
skill_scope: $(if (-not [string]::IsNullOrWhiteSpace($Scope)) { $Scope } elseif (-not [string]::IsNullOrWhiteSpace($entry.Scope)) { $entry.Scope } else { "project" })
skill_path: $skillPath
hit_count: $($entry.HitCount)
reason: $($recommendation.Reason)
"@
Set-Content -LiteralPath $promotionReport -Encoding UTF8 -Value $report

$remaining = @(Get-AllMemoryEntryRecords -Root $Root | Where-Object { Test-MemoryPromotable $_ -HitThreshold $HitThreshold } | Sort-Object Title | Sort-Object HitCount -Descending)
Write-CandidateFile $remaining
Write-Host "Promoted $($entry.Id) to $skillPath and removed the original memory entry."
