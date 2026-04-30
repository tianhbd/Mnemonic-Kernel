param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Description,
    [Parameter(Mandatory = $true)][string]$Trigger,
    [Parameter(Mandatory = $true)][string]$Workflow,
    [Parameter(Mandatory = $true)][string]$Verification,
    [switch]$Confirmed,
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

if (-not $Confirmed) {
    throw "Refusing to create skill without explicit -Confirmed."
}

$slug = ($Name.ToLowerInvariant() -replace "[^a-z0-9\-]+", "-").Trim("-")
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

New-Item -ItemType Directory -Path $skillDir | Out-Null
$body = @"
---
name: $slug
description: $Description
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
Add-Content -LiteralPath $index -Encoding UTF8 -Value "| $Name | ``skills/$slug/SKILL.md`` | $Trigger |"

Write-Host "Created skills/$slug/SKILL.md and updated skills/skills.md"
