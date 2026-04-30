param(
    [Parameter(Mandatory = $true)][string]$UserText,
    [Parameter(Mandatory = $true)][string]$AssistantSummary,
    [string[]]$Actions = @(),
    [datetime]$Time = (Get-Date),
    [int]$MaxTurns = 10,
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = (Resolve-Path (Join-Path $scriptDir "..")).Path
}

$journalRoot = Join-Path $Root "journal"
$bufferRoot = Join-Path $journalRoot "buffer"
$currentPath = Join-Path $bufferRoot "current.md"
$metaPath = Join-Path $bufferRoot "meta.json"
$extractedRoot = Join-Path $journalRoot "extracted"
$discardedRoot = Join-Path $journalRoot "discarded"

foreach ($dir in @($bufferRoot, $extractedRoot, $discardedRoot, (Join-Path $journalRoot "reports"))) {
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
        if (-not (Test-Path -LiteralPath $dir)) {
            continue
        }
        Get-ChildItem -LiteralPath $dir -File -Filter "$fileDate-*.md" | ForEach-Object {
            if ($_.BaseName -match "^\d{4}-\d{2}-\d{2}-(\d{3})$") {
                $maxSeq = [Math]::Max($maxSeq, [int]$matches[1])
            }
        }
    }

    return ("{0}-{1:D3}" -f $dateToken, ($maxSeq + 1))
}

function New-Meta {
    param([string]$BatchId, [int]$Turns, [int]$Threshold, [string]$Started, [string]$Updated)
    return [pscustomobject]@{
        batch_id = $BatchId
        turn_count = $Turns
        max_turns = $Threshold
        started = $Started
        last_updated = $Updated
    }
}

function Write-CurrentFile {
    param([string]$BatchId, [string]$Started, [int]$TurnCount, [string]$ExistingTurns)
    $content = @"
# Journal Buffer

batch_id: $BatchId
started: $Started
turn_count: $TurnCount

---
"@
    if (-not [string]::IsNullOrWhiteSpace($ExistingTurns)) {
        $content += "`n`n" + $ExistingTurns.Trim()
    }
    Set-Content -LiteralPath $currentPath -Encoding UTF8 -Value $content
}

if ((-not (Test-Path -LiteralPath $metaPath)) -or (-not (Test-Path -LiteralPath $currentPath))) {
    $startedText = $Time.ToString("yyyy-MM-dd HH:mm")
    $batchId = Get-NextBatchId $Time
    $meta = New-Meta -BatchId $batchId -Turns 0 -Threshold $MaxTurns -Started $startedText -Updated $startedText
    $meta | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metaPath -Encoding UTF8
    Write-CurrentFile -BatchId $batchId -Started $startedText -TurnCount 0 -ExistingTurns ""
}

$meta = Get-Content -Raw -Encoding UTF8 $metaPath | ConvertFrom-Json
$turnNumber = [int]$meta.turn_count + 1
$timeText = $Time.ToString("yyyy-MM-dd HH:mm")

$actionsText = if ($Actions.Count -gt 0) {
    ($Actions | ForEach-Object { "- $(Redact-SecretText $_)" }) -join "`n"
} else {
    "- no recorded actions"
}

$turnBlock = @"
## Turn $turnNumber

time: $timeText
user:
$(Redact-SecretText $UserText)

assistant:
$(Redact-SecretText $AssistantSummary)

actions:
$actionsText
"@

$currentContent = Get-Content -Raw -Encoding UTF8 $currentPath
$existingTurns = ""
if ($currentContent -match "(?ms)^# Journal Buffer.*?^---\s*(.*)$") {
    $existingTurns = $matches[1].Trim()
}
if ([string]::IsNullOrWhiteSpace($existingTurns)) {
    $existingTurns = $turnBlock
} else {
    $existingTurns = $existingTurns.Trim() + "`n`n---`n`n" + $turnBlock
}

$meta.turn_count = $turnNumber
$meta.max_turns = $MaxTurns
$meta.last_updated = $timeText
$meta | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metaPath -Encoding UTF8
Write-CurrentFile -BatchId $meta.batch_id -Started $meta.started -TurnCount $turnNumber -ExistingTurns $existingTurns

$shouldExtract = [int]$meta.turn_count -ge [int]$meta.max_turns
Write-Host "batch_id: $($meta.batch_id)"
Write-Host "turn_count: $($meta.turn_count)"
Write-Host "should_extract: $shouldExtract"
