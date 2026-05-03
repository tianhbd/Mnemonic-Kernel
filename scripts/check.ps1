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
$utilsPath = Join-Path $scriptDir "memory-skill-utils.ps1"
. ([scriptblock]::Create((Get-Content -Raw -Encoding UTF8 $utilsPath)))
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
}

function Test-RequiredFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath (Join-Path $Root $Path) -PathType Leaf)) {
        Add-Failure "Missing required file: $Path"
    }
}

function Test-RequiredDirectory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath (Join-Path $Root $Path) -PathType Container)) {
        Add-Failure "Missing required directory: $Path"
    }
}

function Get-RelativeMarkdownPaths {
    param([string]$Path)
    $content = Get-Content -Raw -Encoding UTF8 (Join-Path $Root $Path)
    [regex]::Matches($content, '`([^`]+\.md)`') | ForEach-Object {
        $_.Groups[1].Value
    } | Where-Object {
        $_ -notmatch "^\w+://" -and $_ -notmatch "[{}<>*]" -and $_ -match "[/\\]"
    } | Select-Object -Unique
}

function Test-IndexReferences {
    param([string]$Path)
    foreach ($ref in Get-RelativeMarkdownPaths $Path) {
        if ($ref -like "*/README.md" -or $ref -like "*.md") {
            $candidate = Join-Path $Root $ref
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                Add-Failure "$Path references missing file: $ref"
            }
        }
    }
}

function Test-TemplateFields {
    param(
        [string]$Path,
        [string[]]$Fields
    )
    $content = Get-Content -Raw -Encoding UTF8 (Join-Path $Root $Path)
    foreach ($field in $Fields) {
        if ($content -notmatch [regex]::Escape("- ${field}:")) {
            Add-Failure "$Path is missing template field: $field"
        }
    }
}

function Test-SecretPatterns {
    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "sk-[A-Za-z0-9_-]{20,}",
        "ghp_[A-Za-z0-9_]{20,}",
        "github_pat_[A-Za-z0-9_]{20,}",
        "xox[baprs]-[A-Za-z0-9-]{20,}",
        "AKIA[0-9A-Z]{16}"
    )
    $scanTargets = @(
        "AGENTS.md",
        "README.md",
        "memory",
        "skills",
        "journal",
        "templates",
        "scripts",
        "tests",
        "docs"
    )

    $files = @()
    foreach ($target in $scanTargets) {
        $path = Join-Path $Root $target
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }
        $item = Get-Item -LiteralPath $path
        if ($item.PSIsContainer) {
            $files += @(Get-ChildItem -LiteralPath $path -Recurse -File)
        } else {
            $files += @($item)
        }
    }

    foreach ($file in $files) {
        $content = Get-Content -Raw -Encoding UTF8 $file.FullName -ErrorAction SilentlyContinue
        foreach ($pattern in $patterns) {
            if ($content -match $pattern) {
                $relative = $file.FullName.Substring((Resolve-Path -LiteralPath $Root).Path.TrimEnd("\").Length + 1).Replace("\", "/")
                Add-Failure "Possible secret pattern in ${relative}: $pattern"
            }
        }
    }
}

function Test-MemoryEntrySchema {
    $entryRoot = Join-Path $Root "memory/entries"
    if (-not (Test-Path -LiteralPath $entryRoot)) {
        Add-Failure "Missing memory entries directory: memory/entries"
        return
    }

    $requiredFields = @("id", "created", "updated", "scope", "type", "status", "risk", "pinned", "trigger", "summary", "content", "source")
    foreach ($file in Get-ChildItem -LiteralPath $entryRoot -Recurse -File -Filter "*.md") {
        $relative = $file.FullName.Substring((Resolve-Path -LiteralPath $Root).Path.TrimEnd("\").Length + 1).Replace("\", "/")
        $content = Get-Content -Raw -Encoding UTF8 $file.FullName
        foreach ($field in $requiredFields) {
            if ($content -notmatch "(?m)^$([regex]::Escape($field)):\s*") {
                Add-Failure "$relative is missing memory entry field: $field"
            }
        }
        if ($relative -notmatch "^memory/entries/\d{4}-\d{2}-\d{2}/\d{4}-.+\.md$") {
            Add-Failure "$relative does not follow memory/entries/YYYY-MM-DD/HHmm-slug.md"
        }
        if ($content -notmatch "(?m)^id:\s*\d{8}-\d{4}-.+\s*$") {
            Add-Failure "$relative has invalid id format"
        }
        # Validate scope value
        $scopeMatch = [regex]::Match($content, "(?m)^scope:\s*(\S+)\s*$")
        if ($scopeMatch.Success) {
            $scopeValue = $scopeMatch.Groups[1].Value
            if ($scopeValue -notin @("project", "global")) {
                Add-Failure "$relative has invalid scope value: $scopeValue (must be project or global)"
            }
        }
    }
}

function Test-MemoryIndexes {
    $indexRoot = Join-Path $Root "memory/index"
    if (-not (Test-Path -LiteralPath $indexRoot)) {
        Add-Failure "Missing memory index directory: memory/index"
        return
    }

    foreach ($required in @("default.md", "current-week.md", "cold.md", "master.md")) {
        if (-not (Test-Path -LiteralPath (Join-Path $indexRoot $required))) {
            Add-Failure "Missing memory index file: memory/index/$required"
        }
    }

    $default = Join-Path $indexRoot "default.md"
    if (Test-Path -LiteralPath $default) {
        $defaultContent = Get-Content -Raw -Encoding UTF8 $default
        if ($defaultContent -notmatch "(?m)^## recent-3d\s*$") {
            Add-Failure "memory/index/default.md is missing recent-3d section"
        }
        if ($defaultContent -notmatch "(?m)^## hot\s*$") {
            Add-Failure "memory/index/default.md is missing hot section"
        }
    }

    foreach ($index in Get-ChildItem -LiteralPath $indexRoot -File -Filter "*.md") {
        $relative = $index.FullName.Substring((Resolve-Path -LiteralPath $Root).Path.TrimEnd("\").Length + 1).Replace("\", "/")
        $content = Get-Content -Raw -Encoding UTF8 $index.FullName
        if ($content -match "(?m)^(content|source):\s*$") {
            Add-Failure "$relative appears to contain entry body fields"
        }
        foreach ($match in [regex]::Matches($content, "(?m)^\s*path:\s*(memory/entries/.+?\.md)\s*$")) {
            $target = Join-Path $Root ($match.Groups[1].Value -replace "/", "\")
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                Add-Failure "$relative references missing entry: $($match.Groups[1].Value)"
            }
        }
    }
}

function Test-AgentsMemoryRule {
    $content = Get-Content -Raw -Encoding UTF8 (Join-Path $Root "AGENTS.md")
    if ($content -match 'load only `memory/memory\.md` by default' -or $content -match '默认只加载\s*`memory/memory\.md`') {
        Add-Failure "AGENTS.md still requires default loading of memory/memory.md"
    }
    if ($content -notmatch "memory/index/default\.md") {
        Add-Failure "AGENTS.md does not mention memory/index/default.md as the default memory index"
    }
}

function Test-JournalStructure {
    foreach ($required in @("journal/buffer", "journal/extracted", "journal/discarded", "journal/reports")) {
        Test-RequiredDirectory $required
    }

    $metaPath = Join-Path $Root "journal/buffer/meta.json"
    if (Test-Path -LiteralPath $metaPath) {
        try {
            $meta = Get-Content -Raw -Encoding UTF8 $metaPath | ConvertFrom-Json
            foreach ($field in @("batch_id", "turn_count", "max_turns", "started", "last_updated")) {
                if (-not ($meta.PSObject.Properties.Name -contains $field)) {
                    Add-Failure "journal/buffer/meta.json is missing field: $field"
                }
            }
        } catch {
            Add-Failure "journal/buffer/meta.json is not valid JSON"
        }
    }

    $currentPath = Join-Path $Root "journal/buffer/current.md"
    if (Test-Path -LiteralPath $currentPath) {
        $content = Get-Content -Raw -Encoding UTF8 $currentPath
        foreach ($pattern in @("(?m)^# Journal Buffer\s*$", "(?m)^batch_id:\s*\S+\s*$", "(?m)^started:\s*.+$", "(?m)^turn_count:\s*\d+\s*$")) {
            if ($content -notmatch $pattern) {
                Add-Failure "journal/buffer/current.md does not match the required journal buffer format"
                break
            }
        }
    }
}

function Test-AgentsJournalRule {
    $content = Get-Content -Raw -Encoding UTF8 (Join-Path $Root "AGENTS.md")
    if ($content -notmatch "journal-append\.ps1") {
        Add-Failure "AGENTS.md does not mention scripts/journal-append.ps1"
    }
    if ($content -notmatch "journal-extract\.ps1") {
        Add-Failure "AGENTS.md does not mention scripts/journal-extract.ps1"
    }
    if ($content -notmatch 'journal.*not default context') {
        Add-Failure "AGENTS.md does not state that journal is not default context"
    }
    if ($content -notmatch 'must not create skills automatically') {
        Add-Failure "AGENTS.md does not forbid automatic skill creation from journal"
    }
}

function Test-SkillDefinitions {
    $skillIndexPath = Join-Path $Root "skills/skills.md"
    $skillIndexContent = if (Test-Path -LiteralPath $skillIndexPath -PathType Leaf) {
        Get-Content -Raw -Encoding UTF8 $skillIndexPath
    } else {
        ""
    }
    $indexedPaths = @([regex]::Matches($skillIndexContent, '`(skills/.+?/SKILL\.md)`') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notmatch '[{}<>]' })
    $skills = @(Get-AllSkillRecords -Root $Root)

    foreach ($skill in $skills) {
        if ($indexedPaths -notcontains $skill.Path) {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($skill.Frontmatter)) {
            Add-Failure "$($skill.Path) is missing YAML frontmatter"
            continue
        }
        if ([string]::IsNullOrWhiteSpace($skill.Name)) {
            Add-Failure "$($skill.Path) is missing frontmatter field: name"
        }
        if ([string]::IsNullOrWhiteSpace($skill.Description)) {
            Add-Failure "$($skill.Path) is missing frontmatter field: description"
        }
        $globalRoot = Join-Path $env:USERPROFILE ".config\opencode"
        $isGlobalRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd("\") -ieq (Resolve-Path -LiteralPath $globalRoot -ErrorAction SilentlyContinue).Path.TrimEnd("\")
        $isLegacyExternalSkill = $isGlobalRoot -and [string]::IsNullOrWhiteSpace($skill.Category) -and @($skill.Triggers).Count -eq 0
        if (-not $isLegacyExternalSkill -and [string]::IsNullOrWhiteSpace($skill.Category)) {
            Add-Failure "$($skill.Path) is missing frontmatter field: category"
        }
        if (-not $isLegacyExternalSkill -and @($skill.Triggers).Count -eq 0) {
            Add-Failure "$($skill.Path) is missing frontmatter field: triggers"
        }
        if (-not $isLegacyExternalSkill -and -not $skill.ScopeOverridden -and [string]::IsNullOrWhiteSpace($skill.Scope)) {
            Add-Failure "$($skill.Path) is missing frontmatter scope.value"
        }
        # Validate scope value
        if (-not $isLegacyExternalSkill -and -not [string]::IsNullOrWhiteSpace($skill.Scope)) {
            if ($skill.Scope -notin @("project", "global")) {
                Add-Failure "$($skill.Path) has invalid scope value: $($skill.Scope) (must be project or global)"
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($skill.PromotedFromMemoryId)) {
            if ([string]::IsNullOrWhiteSpace($skill.PromotedFromMemoryPath)) {
                Add-Failure "$($skill.Path) is missing promoted_from_memory.path"
            } else {
                $promotedPath = Convert-ToAbsoluteRepoPath -RepoPath $skill.PromotedFromMemoryPath -Root $Root
                if (Test-Path -LiteralPath $promotedPath -PathType Leaf) {
                    Add-Failure "$($skill.Path) still points to existing promoted memory: $($skill.PromotedFromMemoryPath)"
                }
            }
            if ($skill.PromotedFromMemoryHitCount -le 0) {
                Add-Failure "$($skill.Path) has invalid promoted_from_memory.hit_count"
            }
            if ([string]::IsNullOrWhiteSpace($skill.PromotedAt)) {
                Add-Failure "$($skill.Path) is missing promoted_from_memory.promoted_at"
            }
        }
    }

    foreach ($indexedPath in $indexedPaths) {
        $absolute = Convert-ToAbsoluteRepoPath -RepoPath $indexedPath -Root $Root
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
            Add-Failure "skills/skills.md references missing skill file: $indexedPath"
        }
    }
}

function Test-DiscardedSkillSuppressions {
    $discardRoot = Join-Path $Root "journal/discarded"
    if (-not (Test-Path -LiteralPath $discardRoot -PathType Container)) {
        return
    }

    $skillNames = @((Get-AllSkillRecords -Root $Root) | ForEach-Object { $_.Name })
    foreach ($file in Get-ChildItem -LiteralPath $discardRoot -File -Filter "*.md") {
        $content = Get-Content -Raw -Encoding UTF8 $file.FullName
        $reason = Get-MarkdownScalarField -Content $content -Name "reason"
        if ($reason -ne "duplicated_by_skill") {
            continue
        }
        $matchedSkill = Get-MarkdownScalarField -Content $content -Name "matched_skill"
        if ([string]::IsNullOrWhiteSpace($matchedSkill)) {
            Add-Failure "$($file.FullName.Substring((Resolve-Path -LiteralPath $Root).Path.TrimEnd('\').Length + 1).Replace('\', '/')) is missing matched_skill for duplicated_by_skill"
            continue
        }
        if ($skillNames -notcontains $matchedSkill) {
            Add-Failure "$($file.FullName.Substring((Resolve-Path -LiteralPath $Root).Path.TrimEnd('\').Length + 1).Replace('\', '/')) points to missing skill: $matchedSkill"
        }
    }
}

function Test-SkillPromotionCandidates {
    $candidatePath = Join-Path $Root "memory/review/skill-promote-candidates.md"
    if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
        return
    }

    $content = Get-Content -Raw -Encoding UTF8 $candidatePath
    $ids = @([regex]::Matches($content, '(?m)^- memory_id:\s*(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
    $paths = @([regex]::Matches($content, '(?m)^- path:\s*(memory/entries/.+?\.md)\s*$') | ForEach-Object { $_.Groups[1].Value.Trim() })
    if ($ids.Count -ne $paths.Count) {
        Add-Failure "memory/review/skill-promote-candidates.md has mismatched memory_id/path entries"
        return
    }

    for ($i = 0; $i -lt $ids.Count; $i += 1) {
        $repoPath = $paths[$i]
        $absolute = Convert-ToAbsoluteRepoPath -RepoPath $repoPath -Root $Root
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
            Add-Failure "memory/review/skill-promote-candidates.md references missing memory entry: $repoPath"
            continue
        }
        $entryContent = Get-Content -Raw -Encoding UTF8 $absolute
        $entryId = Get-MarkdownScalarField -Content $entryContent -Name "id"
        if ($entryId -ne $ids[$i]) {
            Add-Failure "memory/review/skill-promote-candidates.md points to $repoPath but id does not match $($ids[$i])"
        }
    }
}

@(
    "README.md",
    "AGENTS.md",
    "memory/memory.md",
    "memory/index/default.md",
    "memory/index/master.md",
    "skills/skills.md",
    "journal/README.md",
    "journal/buffer/current.md",
    "journal/buffer/meta.json",
    "journal/reports/extract-report.md",
    "tests/checklist.md",
    "templates/memory-candidate.md",
    "templates/skill-candidate.md",
    "templates/pending-block.md",
    "scripts/memory-index.ps1",
    "scripts/memory-boot.ps1",
    "scripts/memory-search.ps1",
    "scripts/memory-maintain.ps1",
    "scripts/memory-skill-utils.ps1",
    "scripts/new-skill.ps1",
    "scripts/skill-promote.ps1",
    "scripts/journal-append.ps1",
    "scripts/journal-extract.ps1",
    "scripts/journal-clean.ps1"
) | ForEach-Object { Test-RequiredFile $_ }

Test-IndexReferences "AGENTS.md"
Test-IndexReferences "memory/memory.md"
Test-IndexReferences "skills/skills.md"
Test-TemplateFields "templates/memory-candidate.md" @("type", "label", "content", "reason", "risk", "action")
Test-TemplateFields "templates/skill-candidate.md" @("name", "description", "trigger", "workflow", "verification", "reason", "action")
Test-TemplateFields "templates/pending-block.md" @("status", "reason", "created_from", "next_action", "content")
Test-MemoryEntrySchema
Test-MemoryIndexes
Test-AgentsMemoryRule
Test-JournalStructure
Test-AgentsJournalRule
Test-SkillDefinitions
Test-DiscardedSkillSuppressions
Test-SkillPromotionCandidates
Test-SecretPatterns

if ($failures.Count -gt 0) {
    Write-Host "Mnemonic Kernel check failed:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Mnemonic Kernel check passed." -ForegroundColor Green
