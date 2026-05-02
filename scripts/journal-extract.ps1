param(
    [string]$BatchFile = "",
    [switch]$Force,
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

$journalRoot = Join-Path $Root "journal"
$bufferRoot = Join-Path $journalRoot "buffer"
$currentPath = Join-Path $bufferRoot "current.md"
$metaPath = Join-Path $bufferRoot "meta.json"
$extractedRoot = Join-Path $journalRoot "extracted"
$discardedRoot = Join-Path $journalRoot "discarded"
$reportPath = Join-Path (Join-Path $journalRoot "reports") "extract-report.md"
$memoryEntryRoot = Join-Path $Root "memory/entries"

foreach ($dir in @($bufferRoot, $extractedRoot, $discardedRoot, (Join-Path $journalRoot "reports"), $memoryEntryRoot)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

function Redact-SecretText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "sk-[A-Za-z0-9_-]{20,}",
        "ghp_[A-Za-z0-9_]{20,}",
        "github_pat_[A-Za-z0-9_]{20,}",
        "xox[baprs]-[A-Za-z0-9-]{20,}",
        "AKIA[0-9A-Z]{16}",
        "(?i)(password|passwd|token|api[_-]?key|secret)\s*[:=]\s*\S+"
    )

    $result = $Text
    foreach ($pattern in $patterns) {
        $result = [regex]::Replace($result, $pattern, "[REDACTED]")
    }
    return $result.Trim()
}

function Get-NextBatchId {
    param([datetime]$Timestamp)
    $dateToken = $Timestamp.ToString("yyyyMMdd")
    $fileDate = $Timestamp.ToString("yyyy-MM-dd")
    $maxSeq = 0

    if (Test-Path -LiteralPath $metaPath) {
        $meta = Get-Content -Raw -Encoding UTF8 $metaPath | ConvertFrom-Json
        if ($meta.batch_id -match "^$dateToken-(\d{3})$") {
            $maxSeq = [Math]::Max($maxSeq, [int]$matches[1])
        }
    }

    foreach ($dir in @($extractedRoot, $discardedRoot)) {
        Get-ChildItem -LiteralPath $dir -File -Filter "$fileDate-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.BaseName -match "^\d{4}-\d{2}-\d{2}-(\d{3})$") {
                $maxSeq = [Math]::Max($maxSeq, [int]$matches[1])
            }
        }
    }

    return ("{0}-{1:D3}" -f $dateToken, ($maxSeq + 1))
}

function Reset-ActiveBatch {
    param([int]$MaxTurns)
    $now = Get-Date
    $timeText = $now.ToString("yyyy-MM-dd HH:mm")
    $batchId = Get-NextBatchId $now
    $meta = [pscustomobject]@{
        batch_id = $batchId
        turn_count = 0
        max_turns = $MaxTurns
        started = $timeText
        last_updated = $timeText
    }
    $meta | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metaPath -Encoding UTF8
    $content = @"
# Journal Buffer

batch_id: $batchId
started: $timeText
turn_count: 0

---
"@
    Set-Content -LiteralPath $currentPath -Encoding UTF8 -Value $content
}

function Get-MeaningfulLines {
    param([string]$Content)
    $raw = $Content -split "\r?\n"
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in $raw) {
        $trimmed = (Redact-SecretText $line).Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -eq "---") { continue }
        if ($trimmed -match "^#") { continue }
        if ($trimmed -match "^(batch_id|started|turn_count|time):") { continue }
        if ($trimmed -in @("user:", "assistant:", "actions:")) { continue }
        $lines.Add($trimmed) | Out-Null
    }
    return @($lines)
}

function Get-CategoryMatches {
    param([string[]]$Lines)

    $definitions = @(
        @{
            type = "user_preference"
            title = "Journal Extracted User Preference"
            keywords = @("user preference", "communication preference", "response style", "prefer", "conclusion first", "language preference", "\u7528\u6237\u504f\u597d", "\u534f\u4f5c\u504f\u597d", "\u4e2d\u6587\u8f93\u51fa", "\u7ed3\u8bba\u4f18\u5148")
            triggers = @("user preference", "journal extract", "response style")
            pinned = $true
        },
        @{
            type = "environment"
            title = "Journal Extracted Environment Fact"
            keywords = @("environment", "machine", "workspace", "runtime", "toolchain", "stable fact", "configuration state", "\u73af\u5883", "\u914d\u7f6e\u72b6\u6001", "\u7a33\u5b9a\u4e8b\u5b9e")
            triggers = @("environment fact", "journal extract", "workspace")
            pinned = $false
        },
        @{
            type = "project_rule"
            title = "Journal Extracted Project Rule"
            keywords = @("rule", "must", "forbid", "hard rule", "constraint", "\u89c4\u5219", "\u5fc5\u987b", "\u7981\u6b62", "\u56fa\u5b9a\u89c4\u5219")
            triggers = @("project rule", "journal extract", "hard rule")
            pinned = $true
        },
        @{
            type = "troubleshooting"
            title = "Journal Extracted Troubleshooting"
            keywords = @("troubleshooting", "error", "fix", "verified", "issue", "bug", "workaround", "\u6392\u969c", "\u9519\u8bef", "\u62a5\u9519", "\u4fee\u590d", "\u9a8c\u8bc1")
            triggers = @("troubleshooting", "journal extract", "verified lesson")
            pinned = $false
        },
        @{
            type = "common_path"
            title = "Journal Extracted Common Path"
            keywords = @("path", "folder", "directory", "\u8def\u5f84", "\u76ee\u5f55")
            triggers = @("common path", "journal extract", "path")
            pinned = $false
        }
    )

    $results = @()
    foreach ($definition in $definitions) {
        $matchedLines = @()
        foreach ($line in $Lines) {
            $keywordHit = $false
            foreach ($keyword in $definition.keywords) {
                if ($line -match $keyword) {
                    $keywordHit = $true
                    break
                }
            }
            $pathHit = $definition.type -eq "common_path" -and ($line -match '[A-Za-z]:\\[^:*?"<>|]+' -or $line -match '(^|[\s])/[A-Za-z0-9._/-]+')
            if (($keywordHit -or $pathHit) -and $line -notmatch "\[REDACTED\]") {
                $matchedLines += $line
            }
        }

        if ($matchedLines.Count -gt 0) {
            $results += [pscustomobject]@{
                Type = $definition.type
                Title = $definition.title
                Trigger = $definition.triggers
                Pinned = $definition.pinned
                Lines = @($matchedLines | Select-Object -Unique | Select-Object -First 4)
            }
        }
    }
    return @($results)
}

function New-MemoryEntryFromJournal {
    param(
        [object]$Candidate,
        [string]$BatchId,
        [string]$ExtractedRelativePath,
        [datetime]$Timestamp
    )

    $dateDirName = $Timestamp.ToString("yyyy-MM-dd")
    $dateDir = Join-Path $memoryEntryRoot $dateDirName
    if (-not (Test-Path -LiteralPath $dateDir)) {
        New-Item -ItemType Directory -Path $dateDir | Out-Null
    }

    $slug = ("journal-" + $Candidate.Type + "-" + $BatchId.ToLowerInvariant()) -replace "[^a-z0-9\-]", "-"
    $slug = $slug.Trim("-")
    $timeToken = $Timestamp.ToString("HHmm")
    $target = Join-Path $dateDir "$timeToken-$slug.md"
    $suffix = 1
    while (Test-Path -LiteralPath $target) {
        $target = Join-Path $dateDir ("{0}-{1}-{2:D2}.md" -f $timeToken, $slug, $suffix)
        $suffix += 1
    }

    $fileSlug = [System.IO.Path]::GetFileNameWithoutExtension($target).Substring(5)
    $id = "{0}-{1}-{2}" -f $Timestamp.ToString("yyyyMMdd"), $timeToken, $fileSlug
    $summary = "Extracted from journal batch $BatchId as $($Candidate.Type)."
    $content = ($Candidate.Lines -join "`n")
    $triggerBlock = ($Candidate.Trigger | ForEach-Object { "- $_" }) -join "`n"

    $body = @"
# $($Candidate.Title)

id: $id
created: $($Timestamp.ToString("yyyy-MM-dd HH:mm"))
updated: $($Timestamp.ToString("yyyy-MM-dd HH:mm"))
scope: project
type: $($Candidate.Type)
status: active
risk: low
pinned: $($Candidate.Pinned.ToString().ToLowerInvariant())
hit_count: 0
last_hit:

trigger:
$triggerBlock

summary:
$summary

content:
$content

source:
$ExtractedRelativePath
"@
    Set-Content -LiteralPath $target -Encoding UTF8 -Value $body
    return (Convert-ToRepoPath -Path $target -Root $Root)
}

if (-not (Test-Path -LiteralPath $metaPath)) {
    Reset-ActiveBatch -MaxTurns 10
}

$meta = Get-Content -Raw -Encoding UTF8 $metaPath | ConvertFrom-Json
$activeBatchPath = if ([string]::IsNullOrWhiteSpace($BatchFile)) { $currentPath } else { $BatchFile }
if (-not (Test-Path -LiteralPath $activeBatchPath)) {
    throw "Batch file not found: $activeBatchPath"
}

$batchContent = Get-Content -Raw -Encoding UTF8 $activeBatchPath
$batchId = if ($batchContent -match "(?m)^batch_id:\s*(\S+)\s*$") { $matches[1] } else { $meta.batch_id }
$turnCount = if ($batchContent -match "(?m)^turn_count:\s*(\d+)\s*$") { [int]$matches[1] } else { [int]$meta.turn_count }
$maxTurns = [int]$meta.max_turns

if (-not $Force -and $turnCount -lt $maxTurns) {
    throw "Current batch has not reached max_turns. Use -Force to extract early."
}

$now = Get-Date
$batchDatePrefix = "{0}-{1}-{2}" -f $batchId.Substring(0, 4), $batchId.Substring(4, 2), $batchId.Substring(6, 2)
$batchFileName = "{0}-{1}.md" -f $batchDatePrefix, $batchId.Substring(9, 3)
$extractedPath = Join-Path $extractedRoot $batchFileName
$discardedPath = Join-Path $discardedRoot $batchFileName
$extractedRelative = "journal/extracted/$batchFileName"

$lines = Get-MeaningfulLines $batchContent
$explicitKeep = $batchContent -match "(?i)remember this|long-term memory|durable memory|\u8bb0\u4f4f\u8fd9\u4e2a|\u957f\u671f\u8bb0\u5fc6|\u6574\u7406\u6210\u957f\u671f\u8bb0\u5fc6"
$candidates = @(Get-CategoryMatches $lines)
$skills = @(Get-AllSkillRecords -Root $Root)
$suppressedMatches = New-Object System.Collections.Generic.List[object]

$memoryPaths = @()
$decision = "discarded"
$discardReason = "no_durable_value"
$matchedSkillName = ""
$reasonLines = @()

if ($candidates.Count -gt 0 -or $explicitKeep) {
    if ($candidates.Count -eq 0 -and $explicitKeep) {
        $candidates = @([pscustomobject]@{
            Type = "mechanism"
            Title = "Journal Extracted Requested Memory"
            Trigger = @("durable memory", "journal extract", "explicit request")
            Pinned = $true
            Lines = @($lines | Select-Object -First 4)
        })
    }

    $remainingCandidates = @()
    foreach ($candidate in $candidates) {
        $matchedSkill = Find-MatchingSkillForCandidate -Candidate $candidate -Skills $skills
        if ($null -ne $matchedSkill) {
            $suppressedMatches.Add([pscustomobject]@{
                Candidate = $candidate
                Skill = $matchedSkill
            }) | Out-Null
            continue
        }
        $remainingCandidates += $candidate
    }

    $candidates = @($remainingCandidates)
    foreach ($candidate in $candidates) {
        $memoryPaths += New-MemoryEntryFromJournal -Candidate $candidate -BatchId $batchId -ExtractedRelativePath $extractedRelative -Timestamp $now
    }

    if ($memoryPaths.Count -gt 0) {
        $summary = "Extracted $($memoryPaths.Count) durable memory entries from batch $batchId."
        $suppressedSummary = if ($suppressedMatches.Count -gt 0) {
            ($suppressedMatches | ForEach-Object { "- duplicated_by_skill: $($_.Skill.Name)" }) -join "`n"
        } else {
            "- none"
        }
        $extractedBody = @"
# Extracted Journal Batch

batch_id: $batchId
time: $($now.ToString("yyyy-MM-dd HH:mm"))
turn_count: $turnCount
decision: extracted

created_entries:
$(($memoryPaths | ForEach-Object { "- $_" }) -join "`n")

suppressed_by_skill:
$suppressedSummary

summary:
$summary
"@
        Set-Content -LiteralPath $extractedPath -Encoding UTF8 -Value $extractedBody
        if (Test-Path -LiteralPath $discardedPath) {
            Remove-Item -LiteralPath $discardedPath -Force
        }
        & (Join-Path $scriptDir "memory-index.ps1") -Root $Root | Out-Null
        $decision = "extracted"
    } else {
        $discardReason = "duplicated_by_skill"
        if ($suppressedMatches.Count -gt 0) {
            $matchedSkillName = $suppressedMatches[0].Skill.Name
            $reasonLines = @($suppressedMatches | ForEach-Object { "matched skill: $($_.Skill.Name)" } | Select-Object -Unique)
        }
    }
}

if ($decision -ne "extracted") {
    if ($reasonLines.Count -eq 0) {
        $reasonLines = @(
            "No durable preference detected",
            "No stable environment fact detected",
            "No reusable troubleshooting lesson detected"
        )
    }
    $discardBody = @"
# Discarded Journal Batch

batch_id: $batchId
time: $($now.ToString("yyyy-MM-dd HH:mm"))
turn_count: $turnCount
decision: discarded
reason: $discardReason
matched_skill: $matchedSkillName
notes:
$(($reasonLines | ForEach-Object { "- $_" }) -join "`n")
"@
    Set-Content -LiteralPath $discardedPath -Encoding UTF8 -Value $discardBody
    if (Test-Path -LiteralPath $extractedPath) {
        Remove-Item -LiteralPath $extractedPath -Force
    }
}

$reportBody = @"
# Journal Extract Report

time: $($now.ToString("yyyy-MM-dd HH:mm"))
batch_id: $batchId
turn_count: $turnCount

result:
$decision

memory_created:
$($memoryPaths.Count)

suppressed_by_skill:
$($suppressedMatches.Count)

memory_paths:
$(if ($memoryPaths.Count -gt 0) { ($memoryPaths | ForEach-Object { "- $_" }) -join "`n" } else { "- none" })

actions:
- $(if ($decision -eq "extracted") { "cleared journal/buffer/current.md" } else { "discarded active buffer content" })
- reset journal/buffer/meta.json
- $(if ($decision -eq "extracted") { "updated memory index" } else { "no memory index update required" })
- $(if ($suppressedMatches.Count -gt 0) { "suppressed durable memory because an existing skill already covers the same task" } else { "no skill suppression applied" })
"@
Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value $reportBody

if ([string]::IsNullOrWhiteSpace($BatchFile) -or ((Resolve-Path -LiteralPath $activeBatchPath).Path -eq (Resolve-Path -LiteralPath $currentPath).Path)) {
    Reset-ActiveBatch -MaxTurns $maxTurns
}

Write-Host "result: $decision"
Write-Host "memory_created: $($memoryPaths.Count)"
if ($memoryPaths.Count -gt 0) {
    $memoryPaths | ForEach-Object { Write-Host "memory_path: $_" }
}
