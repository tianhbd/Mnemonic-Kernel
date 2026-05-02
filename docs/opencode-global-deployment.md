# OpenCode Global Deployment

This document describes deploying Mnemonic Kernel into the OpenCode global config directory while preserving the working OpenCode model/provider setup.

Default target:

```text
C:\Users\simo\.config\opencode
```

## Deployment Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1
```

Preview without mutation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1 -WhatIf
```

Custom target:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1 `
  -TargetRoot "C:\Users\simo\.config\opencode"
```

## What Deployment Does

- Creates the target root if missing.
- Creates a backup under `.backup\mnemonic-kernel-<timestamp>` before changing an existing target.
- Copies framework files: `AGENTS.md`, `README.md`, `docs/`, `scripts/`, `templates/`, `tests/`.
- Merges `memory/`, `journal/`, and `skills/` without deleting target-specific files.
- Preserves `opencode.json` provider/model/mcp settings.
- Removes only known conflicting `opencode-agent-memory` entries from `opencode.json` when enabled.
- Runs target `scripts/memory-boot.ps1` after copy so indexes match the deployed memory entries.

## Preserved Data

Deployment intentionally does not remove existing target data:

- existing memory entries under `memory/entries/`
- existing skill bodies under `skills/`
- existing journal buffer files
- existing `opencode.json` provider/model routing
- unrelated OpenCode plugin configuration

If `skills/skills.md` already exists in the target, deployment keeps it. The repository copy is installed only when no target skill index exists.

## Plugin Conflict Rule

`opencode-agent-memory` conflicts with Mnemonic Kernel on this machine because it injects memory files and exposes memory/journal tools outside the index-only loading model.

Deployment removes matching plugin strings from `opencode.json`:

```text
opencode-agent-memory
opencode-agent-memory@...
```

It does not delete provider settings or unrelated plugin entries.

## Verification Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-opencode.ps1
```

Defaults:

```text
TargetRoot = C:\Users\simo\.config\opencode
Model      = llamacpp/27B
ProbeText  = 只回答 ok
```

`verify-opencode.ps1` checks:

- required global files exist
- `AGENTS.md` points to `memory/index/default.md`
- index files do not contain memory body fields
- `scripts/check.ps1 -Root <TargetRoot>` passes
- `opencode-agent-memory` is absent from `opencode.json` plugin list
- `opencode debug config` succeeds
- `opencode run --model llamacpp/27B --format default "只回答 ok"` succeeds

## Runtime Boundary

The intended OpenCode loading boundary after deployment is:

```text
read AGENTS.md
read memory/index/default.md
read skills/skills.md
do not read memory/entries/ by default
do not read journal/ by default
```

Task-time memory lookup must go through the index chain first. Skill bodies must be loaded only after trigger match.

## Rollback

Use the latest backup under:

```text
C:\Users\simo\.config\opencode\.backup\mnemonic-kernel-<timestamp>
```

Restore only the affected files/directories. Do not blindly delete the whole OpenCode config directory unless the target has been backed up and inspected.
