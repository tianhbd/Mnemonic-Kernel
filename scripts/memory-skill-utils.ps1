function Convert-ToRepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $rootPath = (Resolve-Path -LiteralPath $Root).Path.TrimEnd("\")
    $fullPath = (Resolve-Path -LiteralPath $Path).Path
    return $fullPath.Substring($rootPath.Length + 1).Replace("\", "/")
}

function Convert-ToAbsoluteRepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$Root
    )

    return Join-Path $Root ($RepoPath -replace "/", "\")
}

function Get-MarkdownScalarField {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $lines = $Content -split "\r?\n"
    for ($i = 0; $i -lt $lines.Length; $i += 1) {
        if ($lines[$i] -notmatch "^$([regex]::Escape($Name)):[^\S\r\n]*(.*)$") {
            continue
        }

        $inlineValue = $matches[1].Trim()
        if (-not [string]::IsNullOrWhiteSpace($inlineValue)) {
            return $inlineValue
        }

        $values = New-Object System.Collections.Generic.List[string]
        for ($j = $i + 1; $j -lt $lines.Length; $j += 1) {
            if ($lines[$j] -match "^[A-Za-z_][A-Za-z0-9_-]*:\s*") {
                break
            }
            if ($lines[$j] -match "^\s*-\s+" -and $values.Count -eq 0) {
                break
            }
            if ([string]::IsNullOrWhiteSpace($lines[$j])) {
                if ($values.Count -eq 0) {
                    continue
                }
                break
            }
            $values.Add($lines[$j].Trim()) | Out-Null
        }
        return ($values -join "`n").Trim()
    }
    return ""
}

function Get-MarkdownListField {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $items = New-Object System.Collections.Generic.List[string]
    $lines = $Content -split "\r?\n"
    $inside = $false
    foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($Name)):\s*$") {
            $inside = $true
            continue
        }
        if ($inside -and $line -match "^[A-Za-z_][A-Za-z0-9_-]*:\s*") {
            break
        }
        if ($inside -and $line -match "^\s*-\s*(.+?)\s*$") {
            $items.Add($matches[1].Trim()) | Out-Null
        }
    }
    return @($items)
}

function Get-MarkdownTitle {
    param([Parameter(Mandatory = $true)][string]$Content)

    $match = [regex]::Match($Content, "(?m)^#\s+(.+)$")
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return ""
}

function Get-FrontmatterBlock {
    param([Parameter(Mandatory = $true)][string]$Content)

    $match = [regex]::Match($Content, "(?s)^---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|$)")
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return ""
}

function Get-FrontmatterScalar {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $block = Get-FrontmatterBlock $Content
    if ([string]::IsNullOrWhiteSpace($block)) {
        return ""
    }
    $match = [regex]::Match($block, "(?m)^$([regex]::Escape($Name)):[^\S\r\n]*(.*)$")
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return ""
}

function Get-FrontmatterList {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $block = Get-FrontmatterBlock $Content
    if ([string]::IsNullOrWhiteSpace($block)) {
        return @()
    }

    $items = New-Object System.Collections.Generic.List[string]
    $lines = $block -split "\r?\n"
    $inside = $false
    foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($Name)):\s*$") {
            $inside = $true
            continue
        }
        if ($inside -and $line -match "^[A-Za-z_][A-Za-z0-9_-]*:\s*") {
            break
        }
        if ($inside -and $line -match "^\s*-\s*(.+?)\s*$") {
            $items.Add($matches[1].Trim()) | Out-Null
        }
    }
    return @($items)
}

function Get-FrontmatterNestedScalar {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$ParentName,
        [Parameter(Mandatory = $true)][string]$ChildName
    )

    $block = Get-FrontmatterBlock $Content
    if ([string]::IsNullOrWhiteSpace($block)) {
        return ""
    }

    $lines = $block -split "\r?\n"
    $inside = $false
    foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($ParentName)):\s*$") {
            $inside = $true
            continue
        }
        if ($inside -and $line -match "^[A-Za-z_][A-Za-z0-9_-]*:\s*") {
            break
        }
        if ($inside -and $line -match "^\s{2}$([regex]::Escape($ChildName)):\s*(.*)$") {
            return $matches[1].Trim()
        }
    }
    return ""
}

function Get-SearchTokens {
    param([string[]]$Texts)

    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($text in @($Texts)) {
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }
        foreach ($match in [regex]::Matches($text.ToLowerInvariant(), '\p{L}[\p{L}\p{Nd}_\-/\\:.]*|\p{Nd}+')) {
            $token = $match.Value.Trim()
            if ($token.Length -ge 2) {
                [void]$set.Add($token)
            }
        }
    }
    return @($set)
}

function Get-AsciiSlug {
    param(
        [string[]]$Candidates = @(),
        [string]$FallbackPrefix = "skill"
    )

    foreach ($candidate in @($Candidates)) {
        $text = if ($null -eq $candidate) { "" } else { [string]$candidate }
        $slug = (($text.ToLowerInvariant()) -replace "[^a-z0-9]+", "-").Trim("-")
        if (-not [string]::IsNullOrWhiteSpace($slug)) {
            return $slug
        }
    }

    $fallback = ($FallbackPrefix.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($fallback)) {
        $fallback = "skill"
    }
    return $fallback
}

function Get-MemoryEntryRecord {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $content = Get-Content -Raw -Encoding UTF8 $File.FullName
    $hitCount = 0
    [void][int]::TryParse((Get-MarkdownScalarField $content "hit_count"), [ref]$hitCount)

    $frontmatterTitle = Get-MarkdownScalarField $content "title"
    $displayTitle = if (-not [string]::IsNullOrWhiteSpace($frontmatterTitle)) {
        $frontmatterTitle
    } else {
        $markdownTitle = Get-MarkdownTitle $content
        if (-not [string]::IsNullOrWhiteSpace($markdownTitle)) {
            $markdownTitle
        } else {
            $File.BaseName
        }
    }

    [pscustomobject]@{
        Id = Get-MarkdownScalarField $content "id"
        Title = $displayTitle
        Type = Get-MarkdownScalarField $content "type"
        Scope = Get-MarkdownScalarField $content "scope"
        Trigger = @(Get-MarkdownListField $content "trigger")
        Summary = Get-MarkdownScalarField $content "summary"
        Content = Get-MarkdownScalarField $content "content"
        Status = Get-MarkdownScalarField $content "status"
        Risk = Get-MarkdownScalarField $content "risk"
        Pinned = ((Get-MarkdownScalarField $content "pinned") -eq "true")
        HitCount = $hitCount
        LastHit = Get-MarkdownScalarField $content "last_hit"
        Path = Convert-ToRepoPath -Path $File.FullName -Root $Root
        FullPath = $File.FullName
    }
}

function Get-AllMemoryEntryRecords {
    param([Parameter(Mandatory = $true)][string]$Root)

    $entryRoot = Join-Path $Root "memory/entries"
    if (-not (Test-Path -LiteralPath $entryRoot -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $entryRoot -Recurse -File -Filter "*.md" | ForEach-Object {
        Get-MemoryEntryRecord -File $_ -Root $Root
    })
}

function Test-MemoryLooksOneOff {
    param([Parameter(Mandatory = $true)]$Record)

    if ($Record.Type -in @("current_state", "timeline_fact")) {
        return $true
    }

    $combined = @($Record.Title, $Record.Summary, $Record.Content) -join "`n"
    return $combined -match "(?i)\bone[- ]?off\b|\btemporary\b|\badhoc\b|一次性|临时|单次|对话总结|临时总结|session summary"
}

function Test-MemoryPromotable {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [int]$HitThreshold = 5
    )

    if ($Record.HitCount -lt $HitThreshold) {
        return $false
    }
    if ($Record.Type -eq "user_preference") {
        return $false
    }
    if (Test-MemoryLooksOneOff $Record) {
        return $false
    }
    if (@($Record.Trigger).Count -eq 0) {
        return $false
    }
    return $true
}

function Get-SkillCategoryForMemoryType {
    param([Parameter(Mandatory = $true)][string]$Type)

    switch ($Type) {
        "troubleshooting" { return "operations" }
        "project_rule" { return "governance" }
        "mechanism" { return "governance" }
        "common_path" { return "reference" }
        "environment" { return "reference" }
        "environment_fact" { return "reference" }
        "login_info" { return "reference" }
        default { return "reference" }
    }
}

function Get-SkillRecommendationForMemory {
    param([Parameter(Mandatory = $true)]$Record)

    $name = if ([string]::IsNullOrWhiteSpace($Record.Title)) {
        "Promoted $($Record.Type) $($Record.Id)"
    } else {
        $Record.Title
    }
    $slug = Get-AsciiSlug -Candidates @($Record.Title, ($Record.Trigger -join "-")) -FallbackPrefix ("promoted-{0}-{1}" -f $Record.Type, ($Record.Id -replace "[^0-9A-Za-z-]", "").ToLowerInvariant())
    $triggers = @($Record.Trigger | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique | Select-Object -First 4)
    if ($triggers.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($Record.Title)) {
        $triggers = @($Record.Title)
    }
    $category = Get-SkillCategoryForMemoryType $Record.Type

    $workflow = switch ($Record.Type) {
        "troubleshooting" {
@"
1. Match the request against the stored symptom or trigger.
2. Apply the validated troubleshooting steps or command sequence from the promoted memory.
3. Return the exact commands, checks, and expected success signal in a fixed format.
4. Verify the result before closing the task.
"@
        }
        "project_rule" {
@"
1. Detect that the current task matches this project rule.
2. Apply the rule consistently before writing code or documentation.
3. Return the required output format or enforcement steps instead of free-form summary.
4. Verify the final result still follows the stored rule.
"@
        }
        "mechanism" {
@"
1. Match the request to the stored mechanism trigger.
2. Follow the stable operating sequence described by the promoted memory.
3. Output the fixed query template, command sequence, or decision format required by the mechanism.
4. Verify the mechanism outcome with the expected signal.
"@
        }
        "common_path" {
@"
1. Match the request to the stored path or location trigger.
2. Return the exact path, lookup method, and expected usage format.
3. If the task requires action, provide the fixed query or navigation template instead of ad hoc prose.
4. Verify the returned path still exists or is still the intended target.
"@
        }
        "environment" {
@"
1. Match the request to the stored environment trigger.
2. Return the exact machine, runtime, port, or environment fact in a fixed output format.
3. If the task requires action, provide the stable command or query template tied to that environment fact.
4. Verify the fact against the current environment before relying on it.
"@
        }
        "login_info" {
@"
1. Match the request to the stored login or access trigger.
2. Return the login method, account choice, host lookup pattern, and required output format without exposing secret bodies.
3. If the task requires connection, provide the stable access template or command shape.
4. Verify the target identity and access path before use.
"@
        }
        default {
@"
1. Match the request against the stored trigger words.
2. Use the promoted memory as the source of truth for the stable workflow or lookup pattern.
3. Return the fixed command, query template, output format, or decision sequence.
4. Verify the response is complete and still applicable.
"@
        }
    }

    $verification = switch ($Record.Type) {
        "troubleshooting" { "- Re-run the final check and confirm the symptom is gone or the expected signal appears." }
        "common_path" { "- Confirm the returned path resolves to the intended location." }
        "environment" { "- Confirm the environment fact with a direct runtime check when possible." }
        "login_info" { "- Confirm the access method and target identity without exposing credentials." }
        default { "- Confirm the output follows the fixed workflow and matches the stored trigger." }
    }

    $reason = "Promotable durable memory: hit_count=$($Record.HitCount), type=$($Record.Type), reusable trigger set, and stable output/workflow pattern."

    return [pscustomobject]@{
        Name = $name
        Slug = $slug
        Category = $category
        Scope = $Record.Scope
        Triggers = $triggers
        Workflow = $workflow.Trim()
        Verification = $verification
        Reason = $reason
    }
}

function Get-SkillRecord {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $content = Get-Content -Raw -Encoding UTF8 $File.FullName
    $promotedHitCount = 0
    [void][int]::TryParse((Get-FrontmatterNestedScalar $content "promoted_from_memory" "hit_count"), [ref]$promotedHitCount)

    [pscustomobject]@{
        Name = Get-FrontmatterScalar $content "name"
        Description = Get-FrontmatterScalar $content "description"
        Category = Get-FrontmatterScalar $content "category"
        Scope = Get-FrontmatterNestedScalar $content "scope" "value"
        ScopeOverridden = (Get-FrontmatterNestedScalar $content "scope" "overridden") -eq "true"
        OverriddenTo = Get-FrontmatterNestedScalar $content "scope" "overridden_to"
        Triggers = @(Get-FrontmatterList $content "triggers")
        Toolsets = @(Get-FrontmatterList $content "toolsets")
        Path = Convert-ToRepoPath -Path $File.FullName -Root $Root
        FullPath = $File.FullName
        PromotedFromMemoryId = Get-FrontmatterNestedScalar $content "promoted_from_memory" "id"
        PromotedFromMemoryPath = Get-FrontmatterNestedScalar $content "promoted_from_memory" "path"
        PromotedFromMemoryHitCount = $promotedHitCount
        PromotedAt = Get-FrontmatterNestedScalar $content "promoted_from_memory" "promoted_at"
        Frontmatter = Get-FrontmatterBlock $content
    }
}

function Get-AllSkillRecords {
    param([Parameter(Mandatory = $true)][string]$Root)

    $skillRoot = Join-Path $Root "skills"
    if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $skillRoot -Recurse -File -Filter "SKILL.md" | ForEach-Object {
        Get-SkillRecord -File $_ -Root $Root
    })
}

function Find-MatchingSkillForCandidate {
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)][object[]]$Skills
    )

    $candidateTexts = @($Candidate.Type) + @($Candidate.Trigger) + @($Candidate.Lines)
    $candidateCombined = ($candidateTexts -join "`n").ToLowerInvariant()
    $candidateTokens = Get-SearchTokens $candidateTexts

    $best = $null
    $bestScore = -1
    foreach ($skill in $Skills) {
        $score = 0
        foreach ($trigger in @($skill.Triggers)) {
            if ([string]::IsNullOrWhiteSpace($trigger)) {
                continue
            }
            if ($candidateCombined -match [regex]::Escape($trigger.ToLowerInvariant())) {
                $score += 4
            }
        }

        $skillTexts = @($skill.Name, $skill.Description, $skill.Category) + @($skill.Triggers)
        $skillTokens = Get-SearchTokens $skillTexts
        $overlap = @($candidateTokens | Where-Object { $skillTokens -contains $_ })
        if ($overlap.Count -ge 2) {
            $score += 2
        }
        if ($overlap.Count -ge 3) {
            $score += 1
        }

        if (-not [string]::IsNullOrWhiteSpace($skill.Category) -and $skill.Category -eq (Get-SkillCategoryForMemoryType $Candidate.Type)) {
            $score += 1
        }

        if ($score -gt $bestScore) {
            $best = $skill
            $bestScore = $score
        }
    }

    if ($bestScore -ge 4) {
        return $best
    }
    return $null
}

function Get-ScopeEvidence {
    param(
        [string[]]$Lines,
        [string]$CurrentRepoName = "",
        [string]$ExplicitScope = ""
    )

    # 1. Explicit specification (strongest signal)
    if ($ExplicitScope -in @("global", "project")) {
        return [pscustomobject]@{
            Scope          = $ExplicitScope
            GlobalScore    = if ($ExplicitScope -eq "global") { 99 } else { 0 }
            ProjectScore   = if ($ExplicitScope -eq "project") { 99 } else { 0 }
            Certain        = $true
            Reason         = "explicitly_specified"
        }
    }

    $globalScore = 0
    $projectScore = 0
    $reasons = New-Object System.Collections.Generic.List[string]

    $combined = ($Lines -join " ") -replace "\s+", " "

    # 2. Path/Repo ownership detection
    $globalPathPatterns = @(
        "\\\.config\\\\opencode",
        "\.config[/\\]opencode",
        "global config",
        "全局配置", "系统级配置", "所有项目", "跨项目"
    )

    $projectPathPatterns = @(
        "src/", "lib/", "scripts/", "config/", "tests/", "\.git/"
    )

    if (-not [string]::IsNullOrWhiteSpace($CurrentRepoName)) {
        $projectPathPatterns = @([regex]::Escape($CurrentRepoName)) + $projectPathPatterns
    }
    $projectPathPatterns += @("项目路径", "项目文件", "项目脚本", "项目配置", "当前项目", "这个项目", "本项目")

    foreach ($pattern in $globalPathPatterns) {
        if ($combined -match $pattern) {
            $globalScore += 2
            $reasons.Add("path_global: $pattern") | Out-Null
            break
        }
    }

    foreach ($pattern in $projectPathPatterns) {
        if ($combined -match $pattern) {
            $projectScore += 2
            $reasons.Add("path_project: $pattern") | Out-Null
            break
        }
    }

    # 3. Keyword detection
    $globalKeywords = @(
        "用户偏好", "user preference", "内网设备", "internal device",
        "通用工具", "general tool", "通用规则", "跨项目", "cross-project", "cross project",
        "所有项目", "all projects", "全局", "global", "语言偏好", "language preference"
    )

    $projectKeywords = @(
        "项目bug", "project bug", "项目命令", "project command",
        "项目架构", "project architecture", "项目流程", "project workflow",
        "项目规则", "project rule", "当前项目", "this project",
        "本项目", "这个项目", "项目排障", "project troubleshooting"
    )

    foreach ($kw in $globalKeywords) {
        if ($combined -match [regex]::Escape($kw)) {
            $globalScore += 1
            $reasons.Add("keyword_global: $kw") | Out-Null
        }
    }

    foreach ($kw in $projectKeywords) {
        if ($combined -match [regex]::Escape($kw)) {
            $projectScore += 1
            $reasons.Add("keyword_project: $kw") | Out-Null
        }
    }

    # 4. Decision
    $diff = [Math]::Abs($globalScore - $projectScore)
    if ($diff -ge 2) {
        $scope = if ($globalScore -gt $projectScore) { "global" } else { "project" }
        return [pscustomobject]@{
            Scope      = $scope
            GlobalScore = $globalScore
            ProjectScore = $projectScore
            Certain    = $true
            Reason     = ($reasons -join "; ")
        }
    }

    # 5. Uncertain - default to project
    return [pscustomobject]@{
        Scope        = "project"
        GlobalScore  = $globalScore
        ProjectScore = $projectScore
        Certain      = $false
        Reason       = "uncertain (diff=$diff, defaulted to project)"
    }
}
