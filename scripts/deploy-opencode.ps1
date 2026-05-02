[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$TargetRoot = (Join-Path $env:USERPROFILE ".config\opencode"),
    [object]$Backup = $true,
    [object]$DisableConflictingMemoryPlugin = $true
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$TargetRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetRoot)

function Convert-ToBoolean {
    param([object]$Value, [string]$Name)
    if ($Value -is [bool]) {
        return $Value
    }
    if ($Value -is [int]) {
        return [bool]$Value
    }
    $text = ([string]$Value).Trim().ToLowerInvariant()
    if ($text -in @("true", "1", "yes", "y")) {
        return $true
    }
    if ($text -in @("false", "0", "no", "n")) {
        return $false
    }
    throw "Invalid boolean value for ${Name}: $Value"
}

$BackupEnabled = Convert-ToBoolean $Backup "Backup"
$DisableConflictingMemoryPluginEnabled = Convert-ToBoolean $DisableConflictingMemoryPlugin "DisableConflictingMemoryPlugin"

function Write-Step {
    param([string]$Message)
    Write-Host "[deploy-opencode] $Message"
}

function Join-RepoPath {
    param([string]$Root, [string]$RelativePath)
    return Join-Path $Root ($RelativePath -replace "/", "\")
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($Path, "Create directory")) {
            New-Item -ItemType Directory -Path $Path | Out-Null
        }
    }
}

function Copy-FileMerge {
    param(
        [string]$RelativePath,
        [switch]$PreserveExisting
    )

    $source = Join-RepoPath $SourceRoot $RelativePath
    $target = Join-RepoPath $TargetRoot $RelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Source file missing: $RelativePath ($source)"
    }
    if ($PreserveExisting -and (Test-Path -LiteralPath $target -PathType Leaf)) {
        Write-Step "Preserved existing $RelativePath"
        return
    }
    Ensure-Directory (Split-Path -Parent $target)
    if ($PSCmdlet.ShouldProcess($target, "Copy $RelativePath")) {
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

function Copy-DirectoryMerge {
    param(
        [string]$RelativePath,
        [string[]]$PreserveExistingFiles = @()
    )

    $directorySourceRoot = Join-Path $SourceRoot $RelativePath
    if (-not (Test-Path -LiteralPath $directorySourceRoot -PathType Container)) {
        throw "Source directory missing: $RelativePath"
    }

    Get-ChildItem -LiteralPath $directorySourceRoot -Recurse -File | ForEach-Object {
        $sourceFull = $_.FullName
        $childRelative = $sourceFull.Substring($directorySourceRoot.TrimEnd("\").Length + 1)
        $repoRelative = (Join-Path $RelativePath $childRelative).Replace("\", "/")
        $preserve = $PreserveExistingFiles -contains $repoRelative
        Copy-FileMerge -RelativePath $repoRelative -PreserveExisting:($preserve)
    }
}

function Test-DirectoryHasMarkdown {
    param([string]$Path)
    return (Test-Path -LiteralPath $Path -PathType Container) -and
        ((Get-ChildItem -LiteralPath $Path -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue | Select-Object -First 1) -ne $null)
}

function Backup-ExistingTarget {
    if (-not $BackupEnabled) {
        Write-Step "Backup disabled"
        return
    }
    if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) {
        Write-Step "No existing target to back up"
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupRoot = Join-Path $TargetRoot ".backup"
    $backupPath = Join-Path $backupRoot "mnemonic-kernel-$timestamp"
    Ensure-Directory $backupRoot
    Ensure-Directory $backupPath

    Get-ChildItem -LiteralPath $TargetRoot -Force | Where-Object { $_.Name -ne ".backup" } | ForEach-Object {
        $destination = Join-Path $backupPath $_.Name
        if ($PSCmdlet.ShouldProcess($destination, "Back up $($_.FullName)")) {
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
        }
    }
    Write-Step "Backup path: $backupPath"
}

function Disable-ConflictingMemoryPlugin {
    if (-not $DisableConflictingMemoryPluginEnabled) {
        Write-Step "Conflicting memory plugin removal disabled"
        return
    }

    $configPath = Join-Path $TargetRoot "opencode.json"
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        Write-Step "No opencode.json found; skipped plugin check"
        return
    }

    $raw = Get-Content -Raw -Encoding UTF8 $configPath
    $config = $raw | ConvertFrom-Json
    if (-not ($config.PSObject.Properties.Name -contains "plugin")) {
        Write-Step "No plugin section in opencode.json"
        return
    }

    $changed = $false
    $pluginValue = $config.plugin

    if ($pluginValue -is [System.Array]) {
        $kept = @()
        foreach ($plugin in @($pluginValue)) {
            $text = [string]$plugin
            if ($text -match "^opencode-agent-memory(@.*)?$") {
                $changed = $true
                Write-Step "Removed conflicting plugin entry: $text"
            } else {
                $kept += $plugin
            }
        }
        $config.plugin = @($kept)
    } elseif ($pluginValue -is [string]) {
        if ($pluginValue -match "^opencode-agent-memory(@.*)?$") {
            $config.PSObject.Properties.Remove("plugin")
            $changed = $true
            Write-Step "Removed conflicting plugin entry: $pluginValue"
        }
    }

    if ($changed) {
        if ($PSCmdlet.ShouldProcess($configPath, "Update opencode.json plugin list")) {
            $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding UTF8
        }
    } else {
        Write-Step "No conflicting memory plugin entry found"
    }
}

function Invoke-TargetMemoryBoot {
    $boot = Join-Path $TargetRoot "scripts\memory-boot.ps1"
    if (-not (Test-Path -LiteralPath $boot -PathType Leaf)) {
        throw "Target memory boot script missing: $boot"
    }
    if ($PSCmdlet.ShouldProcess($TargetRoot, "Run memory boot")) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $boot -Root $TargetRoot
    }
}

Write-Step "Source: $SourceRoot"
Write-Step "Target: $TargetRoot"

$targetExisted = Test-Path -LiteralPath $TargetRoot -PathType Container
if ($targetExisted) {
    Backup-ExistingTarget
} else {
    Write-Step "No existing target to back up"
}
Ensure-Directory $TargetRoot

Copy-FileMerge "AGENTS.md"
Copy-FileMerge "README.md"
Copy-DirectoryMerge "docs"
Copy-DirectoryMerge "scripts"
Copy-DirectoryMerge "templates"
Copy-DirectoryMerge "tests"

Ensure-Directory (Join-Path $TargetRoot "memory")
Ensure-Directory (Join-Path $TargetRoot "memory\index")
Ensure-Directory (Join-Path $TargetRoot "memory\entries")
Ensure-Directory (Join-Path $TargetRoot "memory\review")
Ensure-Directory (Join-Path $TargetRoot "memory\reports")
Ensure-Directory (Join-Path $TargetRoot "memory\archive")
Copy-FileMerge "memory/memory.md"
Copy-DirectoryMerge "memory/index"
Copy-DirectoryMerge "memory/review"
Copy-DirectoryMerge "memory/reports"
if (Test-DirectoryHasMarkdown (Join-Path $TargetRoot "memory\entries")) {
    Write-Step "Preserved existing memory/entries"
} else {
    Copy-DirectoryMerge "memory/entries"
}

Ensure-Directory (Join-Path $TargetRoot "journal")
Ensure-Directory (Join-Path $TargetRoot "journal\buffer")
Ensure-Directory (Join-Path $TargetRoot "journal\extracted")
Ensure-Directory (Join-Path $TargetRoot "journal\discarded")
Ensure-Directory (Join-Path $TargetRoot "journal\reports")
Copy-FileMerge "journal/README.md"
Copy-FileMerge "journal/buffer/current.md" -PreserveExisting
Copy-FileMerge "journal/buffer/meta.json" -PreserveExisting
Copy-FileMerge "journal/reports/extract-report.md" -PreserveExisting

Ensure-Directory (Join-Path $TargetRoot "skills")
Copy-FileMerge "skills/skills.md" -PreserveExisting
Get-ChildItem -LiteralPath (Join-Path $SourceRoot "skills") -Directory | ForEach-Object {
    $relative = "skills/$($_.Name)"
    if (Test-Path -LiteralPath (Join-Path $TargetRoot $relative) -PathType Container) {
        Write-Step "Preserved existing $relative"
    } else {
        Copy-DirectoryMerge $relative
    }
}

Disable-ConflictingMemoryPlugin
Invoke-TargetMemoryBoot

Write-Step "Deployment completed"
