param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][ValidateSet("current_state", "user_preference", "timeline_fact", "environment", "environment_fact", "troubleshooting", "mechanism", "project_rule", "common_path", "login_info")][string]$Type,
    [Parameter(Mandatory = $true)][string]$Content,
    [Parameter(Mandatory = $true)][string]$Reason,
    [string[]]$Trigger = @(),
    [string]$Scope = "project",
    [ValidateSet("low", "medium", "high")][string]$Risk = "low",
    [switch]$Pinned,
    [switch]$Confirmed,
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = (Resolve-Path (Join-Path $scriptDir "..")).Path
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if (-not $Confirmed) {
    throw "Refusing to write memory without explicit -Confirmed."
}

$slug = ($Label.ToLowerInvariant() -replace "[^a-z0-9\-]+", "-").Trim("-")
if ([string]::IsNullOrWhiteSpace($slug)) {
    throw "Label must contain at least one ASCII letter or number."
}

$now = Get-Date
$date = $now.ToString("yyyy-MM-dd")
$time = $now.ToString("HHmm")
$entryDir = Join-Path (Join-Path $Root "memory/entries") $date
if (-not (Test-Path -LiteralPath $entryDir)) {
    New-Item -ItemType Directory -Path $entryDir | Out-Null
}

$target = Join-Path $entryDir "$time-$slug.md"
if (Test-Path -LiteralPath $target) {
    throw "Memory entry already exists: $target"
}

$entryRoot = Join-Path $Root "memory/entries"
$existing = @(Get-ChildItem -LiteralPath $entryRoot -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object {
    (Get-Content -Raw -Encoding UTF8 $_.FullName) -match "(?m)^id:\s*\d{8}-\d{4}-$([regex]::Escape($slug))\s*$"
})
if ($existing.Count -gt 0) {
    throw "Possible duplicate memory entry for label: $Label"
}

if ($Trigger.Count -eq 0) {
    $Trigger = @($Label, $Title)
}

$triggerBlock = ($Trigger | ForEach-Object { "- $_" }) -join "`n"
$id = "$($now.ToString("yyyyMMdd"))-$time-$slug"
$body = @"
# $Title

id: $id
created: $($now.ToString("yyyy-MM-dd HH:mm"))
updated: $($now.ToString("yyyy-MM-dd HH:mm"))
scope: $Scope
type: $Type
status: active
risk: $Risk
pinned: $($Pinned.IsPresent.ToString().ToLowerInvariant())
hit_count: 0
last_hit:

trigger:
$triggerBlock

summary:
$Reason

content:
$Content

source:
[Memory Candidate] confirmed by user
"@

Set-Content -LiteralPath $target -Value $body -Encoding UTF8
& (Join-Path $scriptDir "memory-index.ps1") -Root $Root | Out-Null

$relative = $target.Substring((Resolve-Path -LiteralPath $Root).Path.TrimEnd("\").Length + 1).Replace("\", "/")
Write-Host "Created $relative and rebuilt memory indexes."
