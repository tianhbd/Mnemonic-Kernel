param(
    [int]$ExtractedRetentionDays = 30,
    [int]$DiscardedRetentionDays = 7,
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = (Resolve-Path (Join-Path $scriptDir "..")).Path
}

$journalRoot = Join-Path $Root "journal"
$extractedRoot = Join-Path $journalRoot "extracted"
$discardedRoot = Join-Path $journalRoot "discarded"
$reportPath = Join-Path (Join-Path $journalRoot "reports") "extract-report.md"
$now = Get-Date

function Remove-ExpiredFiles {
    param([string]$Path, [int]$RetentionDays)
    $removed = 0
    if (Test-Path -LiteralPath $Path) {
        Get-ChildItem -LiteralPath $Path -File -Filter "*.md" | Where-Object {
            $_.Name -ne ".gitkeep" -and ($now - $_.LastWriteTime).TotalDays -gt $RetentionDays
        } | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
            $removed += 1
        }
    }
    return $removed
}

$removedExtracted = Remove-ExpiredFiles -Path $extractedRoot -RetentionDays $ExtractedRetentionDays
$removedDiscarded = Remove-ExpiredFiles -Path $discardedRoot -RetentionDays $DiscardedRetentionDays

if (Test-Path -LiteralPath $reportPath) {
    $content = Get-Content -Raw -Encoding UTF8 $reportPath
    Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value $content
}

Write-Host "removed_extracted: $removedExtracted"
Write-Host "removed_discarded: $removedDiscarded"
