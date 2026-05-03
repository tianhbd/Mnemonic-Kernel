param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Description,
    [Parameter(Mandatory = $true)][string]$Trigger,
    [Parameter(Mandatory = $true)][string]$Workflow,
    [Parameter(Mandatory = $true)][string]$Verification,
    [string]$Slug = "",
    [string]$Category = "general",
    [string[]]$Triggers = @(),
    [string[]]$Toolsets = @("terminal"),
    [string]$PromotedFromMemoryId = "",
    [string]$PromotedFromMemoryPath = "",
    [int]$PromotedFromMemoryHitCount = 0,
    [string]$PromotedAt = "",
    [string]$Scope = "project",
    [string]$ScopeOverridden = "false",
    [string]$OverriddenTo = "",
    [switch]$Confirmed,
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "memory-skill-utils.ps1")

if ($Scope -notin @("project", "global")) {
    throw "Invalid scope value: $Scope. Must be 'project' or 'global'."
}

if (-not $Confirmed) {
    throw "Refusing to create skill without explicit -Confirmed."
}

$slug = if ([string]::IsNullOrWhiteSpace($Slug)) {
    Get-AsciiSlug -Candidates @($Name, $Trigger) -FallbackPrefix "skill"
} else {
    (($Slug.ToLowerInvariant() -replace "[^a-z0-9\-]+", "-").Trim("-"))
}
if ([string]::IsNullOrWhiteSpace($slug)) {
    throw "Name must contain at least one ASCII letter or number."
}

$skillDir = Join-Path (Join-Path $Root "skills") $slug
$target = Join-Path $skillDir "SKILL.md"
$index = Join-Path $Root "skills/skills.md"

if (Test-Path -LiteralPath $skillDir) {
    throw "Skill already exists: skills/$slug"
}

$indexContent = Get-Content -Raw -Encoding UTF8 $index
if ($indexContent -match [regex]::Escape($Name) -or $indexContent -match [regex]::Escape("skills/$slug/SKILL.md")) {
    throw "Possible duplicate skill index entry: $Name"
}

if ($Triggers.Count -eq 0) {
    $Triggers = @($Trigger)
}
$Triggers = @($Triggers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
if ($Triggers.Count -eq 0) {
    throw "At least one trigger is required."
}

$Toolsets = @($Toolsets | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
if ($Toolsets.Count -eq 0) {
    $Toolsets = @("terminal")
}

$triggerBlock = ($Triggers | ForEach-Object { "  - $_" }) -join "`n"
$toolsetBlock = ($Toolsets | ForEach-Object { "  - $_" }) -join "`n"
$promotedBlock = ""
if (-not [string]::IsNullOrWhiteSpace($PromotedFromMemoryId)) {
    if ([string]::IsNullOrWhiteSpace($PromotedFromMemoryPath)) {
        throw "PromotedFromMemoryPath is required when PromotedFromMemoryId is set."
    }
    if ([string]::IsNullOrWhiteSpace($PromotedAt)) {
        $PromotedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    }
    $promotedBlock = @"
promoted_from_memory:
  id: $PromotedFromMemoryId
  path: $PromotedFromMemoryPath
  hit_count: $PromotedFromMemoryHitCount
  promoted_at: $PromotedAt
"@
}
$scopeBlock = @"
scope:
  value: $Scope
  overridden: $ScopeOverridden
"@
if (-not [string]::IsNullOrWhiteSpace($OverriddenTo)) {
    $scopeBlock += "`n  overridden_to: $OverriddenTo"
}

New-Item -ItemType Directory -Path $skillDir | Out-Null
$body = @"
---
name: $slug
description: $Description
category: $Category
triggers:
$triggerBlock
toolsets:
$toolsetBlock
$promotedBlock
$scopeBlock
---

# $Name

## Trigger

- $Trigger

## Input

- User request or task context matching the trigger.

## Workflow

$Workflow

## Output

- Completed reusable workflow result.

## Verification

$Verification
"@

Set-Content -LiteralPath $target -Value $body -Encoding UTF8
Add-Content -LiteralPath $index -Encoding UTF8 -Value "| $Name | ``skills/$slug/SKILL.md`` | $($Triggers -join '; ') |"

Write-Host "Created skills/$slug/SKILL.md and updated skills/skills.md"
