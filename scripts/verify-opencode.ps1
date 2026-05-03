param(
    [string]$TargetRoot = (Join-Path $env:USERPROFILE ".config\opencode"),
    [string]$OpenCodeExe = "",
    [string]$Model = "llamacpp/27B",
    [string]$ProbeText = "只回答 ok"
)

$ErrorActionPreference = "Stop"
$TargetRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetRoot)
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
}

function Write-Step {
    param([string]$Message)
    Write-Host "[verify-opencode] $Message"
}

function Test-RequiredFile {
    param([string]$RelativePath)
    $path = Join-Path $TargetRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Missing required file: $RelativePath"
    }
}

function Resolve-OpenCodeExe {
    if (-not [string]::IsNullOrWhiteSpace($OpenCodeExe)) {
        if (Test-Path -LiteralPath $OpenCodeExe -PathType Leaf) {
            return (Resolve-Path -LiteralPath $OpenCodeExe).Path
        }
        $cmd = Get-Command $OpenCodeExe -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        throw "OpenCode executable not found: $OpenCodeExe"
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "OpenCode\opencode-cli.exe"),
        (Join-Path $env:APPDATA "npm\opencode.cmd")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $command = Get-Command "opencode" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "OpenCode executable not found. Pass -OpenCodeExe."
}

function Invoke-External {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$Label
    )

    Write-Step $Label
    $output = & $FilePath @Arguments 2>&1
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        Add-Failure "$Label failed with exit code $exit. Output: $($output -join ' ')"
    }
    return ($output -join "`n")
}

function Test-LoadingBoundaries {
    $agentsPath = Join-Path $TargetRoot "AGENTS.md"
    if (-not (Test-Path -LiteralPath $agentsPath -PathType Leaf)) {
        return
    }

    $agents = Get-Content -Raw -Encoding UTF8 $agentsPath
    if ($agents -notmatch "memory/index/default\.md") {
        Add-Failure "AGENTS.md does not point to memory/index/default.md"
    }
    if ($agents -match 'load only `memory/memory\.md` by default' -or $agents -match '默认只加载\s*`memory/memory\.md`') {
        Add-Failure "AGENTS.md still uses memory/memory.md as default loading target"
    }
    if ($agents -notmatch "skills/skills\.md") {
        Add-Failure "AGENTS.md does not mention skills/skills.md"
    }
    if ($agents -notmatch 'Do not read `memory/entries/` by default' -and $agents -notmatch 'Never load or scan the full `memory/` directory') {
        Add-Failure "AGENTS.md does not clearly forbid default memory body loading"
    }

    $defaultIndex = Join-Path $TargetRoot "memory\index\default.md"
    if (Test-Path -LiteralPath $defaultIndex -PathType Leaf) {
        $content = Get-Content -Raw -Encoding UTF8 $defaultIndex
        if ($content -match "(?m)^(content|source):\s*$") {
            Add-Failure "memory/index/default.md appears to contain memory body fields"
        }
    }
}

function Test-PluginConfig {
    $configPath = Join-Path $TargetRoot "opencode.json"
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        Write-Step "No opencode.json found; skipped plugin validation"
        return
    }

    $config = Get-Content -Raw -Encoding UTF8 $configPath | ConvertFrom-Json
    $enabled = $false
    if ($config.PSObject.Properties.Name -contains "plugin") {
        foreach ($plugin in @($config.plugin)) {
            if ([string]$plugin -match "^opencode-agent-memory(@.*)?$") {
                $enabled = $true
            }
        }
    }
    if ($enabled) {
        Add-Failure "opencode-agent-memory is still enabled in opencode.json"
    } else {
        Write-Step "agent_memory_enabled: 0"
    }
}

function Test-PathInjection {
    $agentsPath = Join-Path $TargetRoot "AGENTS.md"
    if (-not (Test-Path -LiteralPath $agentsPath -PathType Leaf)) {
        Add-Failure "AGENTS.md not found at target: $agentsPath"
        return
    }

    $content = Get-Content -Raw -Encoding UTF8 $agentsPath

    # Check for unresolved placeholders like {{OPENCODE_GLOBAL_ROOT}}
    $placeholders = [regex]::Matches($content, '\{\{[A-Z_]+\}\}')
    if ($placeholders.Count -gt 0) {
        $placeholderNames = $placeholders | ForEach-Object { $_.Value } | Sort-Object -Unique
        Add-Failure "AGENTS.md contains unresolved placeholders: $($placeholderNames -join ', ')"
        Write-Step "Path injection FAILED: found $($placeholders.Count) unresolved placeholder(s)"
    } else {
        Write-Step "Path injection verified: no unresolved placeholders in AGENTS.md"
    }
}

function Test-NarrativeConsistency {
    $readmePath = Join-Path $TargetRoot "README.md"
    if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
        Add-Failure "README.md not found at target: $readmePath"
        return
    }

    $content = Get-Content -Raw -Encoding UTF8 $readmePath

    $oldNarratives = @(
        'standalone governance skeleton',
        'standalone agent governance'
    )

    $foundOld = $false
    foreach ($old in $oldNarratives) {
        if ($content -match [regex]::Escape($old)) {
            Add-Failure "README.md still contains old narrative: '$old'"
            $foundOld = $true
        }
    }

    if (-not $foundOld) {
        Write-Step "Narrative consistency verified: no old narrative found in README.md"
    }

    # Check for dual-mode architecture mention
    if ($content -notmatch 'dual.mode' -and $content -notmatch 'adapter' -and $content -notmatch '\u9002\u914d\u5668') {
        Add-Failure "README.md does not mention dual-mode architecture or adapter layer"
    }
}

if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) {
    throw "TargetRoot not found: $TargetRoot"
}

Write-Step "Target: $TargetRoot"
foreach ($file in @(
    "AGENTS.md",
    "README.md",
    "docs/architecture.md",
    "docs/opencode-global-deployment.md",
    "memory/index/default.md",
    "skills/skills.md",
    "scripts/check.ps1",
    "scripts/deploy-opencode.ps1",
    "scripts/verify-opencode.ps1",
    "scripts/memory-boot.ps1",
    "scripts/journal-append.ps1",
    "scripts/journal-extract.ps1"
)) {
    Test-RequiredFile $file
}

Test-LoadingBoundaries
Test-PluginConfig
Test-PathInjection
Test-NarrativeConsistency

$check = Join-Path $TargetRoot "scripts\check.ps1"
if (Test-Path -LiteralPath $check -PathType Leaf) {
    $checkOutput = Invoke-External -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $check, "-Root", $TargetRoot) -Label "framework self-check"
    Write-Host $checkOutput
}

$resolvedOpenCode = Resolve-OpenCodeExe
Write-Step "OpenCode: $resolvedOpenCode"
Push-Location $TargetRoot
try {
    [void](Invoke-External -FilePath $resolvedOpenCode -Arguments @("debug", "config") -Label "opencode debug config")
    $runOutput = Invoke-External -FilePath $resolvedOpenCode -Arguments @("run", "--model", $Model, "--format", "default", $ProbeText) -Label "opencode run"
    Write-Host $runOutput
} finally {
    Pop-Location
}

if ($failures.Count -gt 0) {
    Write-Host "OpenCode verification failed:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

Write-Host "OpenCode verification passed." -ForegroundColor Green
