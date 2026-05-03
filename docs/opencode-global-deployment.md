# OpenCode Global Deployment

This document describes deploying Mnemonic Kernel into the OpenCode global config directory while preserving the working OpenCode model/provider setup.

Default target:

```text
C:\Users\simo\.config\opencode
```

## 双模架构概述 (Dual-Mode Architecture)

Mnemonic Kernel 是通用记忆治理框架，不绑定任何特定 agent runtime。它通过适配器层接入具体环境。当前提供 OpenCode 适配器。

```text
┌──────────────────────────────────────────────────────────┐
│            通用记忆治理框架 (Universal Governance Core)    │
│                                                          │
│  AGENTS.md  = 硬规则、入口、加载边界                       │
│  memory     = 长期事实、偏好、规则、排障经验                │
│  skills     = 可重复执行的稳定流程                         │
│  journal    = 短期交互缓冲，作为 memory 的提炼来源          │
│                                                          │
│  通用治理核不依赖任何特定 runtime                          │
└───────────────────────┬──────────────────────────────────┘
                        │ 适配器层 (Adapter Layer)
                        ▼
              ┌─────────────────┐
              │  OpenCode 适配层  │
              │                 │
              │  · 路径注入       │
              │  · AGENTS.md 增强 │
              │  · deploy 机制    │
              └─────────────────┘
```

The universal governance core is runtime-agnostic. The OpenCode adapter handles three things:
- **Path Injection**: Replaces `{{OPENCODE_GLOBAL_ROOT}}` placeholders with actual runtime paths
- **AGENTS.md Enhancement**: Injects global path rules, Desktop loading timing, and Journal Append behavior refinement
- **Deploy Mechanism**: `deploy-opencode.ps1` creates backups, preserves existing configuration, and removes conflicting plugins

## 路径注入机制 (Path Injection)

项目版 `AGENTS.md` 中使用 `{{OPENCODE_GLOBAL_ROOT}}` 占位符代替硬编码路径。这使得同一份 `AGENTS.md` 既能作为项目内文档使用，又能通过 deploy 脚本注入实际路径后部署到任意 OpenCode 全局目录。

### 占位符位置 (Placeholder Locations)

`AGENTS.md` 中所有涉及全局路径的位置使用 `{{OPENCODE_GLOBAL_ROOT}}`：

```text
{{OPENCODE_GLOBAL_ROOT}}
{{OPENCODE_GLOBAL_ROOT}}\scripts
{{OPENCODE_GLOBAL_ROOT}}\scripts\memory-boot.ps1
{{OPENCODE_GLOBAL_ROOT}}\scripts\journal-append.ps1
{{OPENCODE_GLOBAL_ROOT}}\scripts\journal-extract.ps1
{{OPENCODE_GLOBAL_ROOT}}\scripts\memory-index.ps1
```

### 注入流程 (Injection Flow)

1. 项目仓库中 `AGENTS.md` 保留 `{{OPENCODE_GLOBAL_ROOT}}` 占位符
2. 运行 `deploy-opencode.ps1` 时，脚本将占位符替换为 `-TargetRoot` 指定的实际路径
3. 替换后的 `AGENTS.md` 写入目标目录，不再包含占位符
4. 后续 `verify-opencode.ps1` 检查部署后的文件不含残留占位符

### 参数说明 (Parameters)

| 参数 | 说明 | 默认值 |
|---|---|---|
| `-TargetRoot` | OpenCode 全局配置目录路径 | `$env:USERPROFILE\.config\opencode` |
| `-WhatIf` | 预演模式，只列出操作不执行 | 不启用 |
| `-Backup` | 是否创建备份 | `true` |
| `-DisableConflictingMemoryPlugin` | 是否移除冲突插件 | `true` |

`-TargetRoot` 既指定部署目标目录，也作为路径注入的替换值。例如 `-TargetRoot "D:\custom\opencode"` 会将所有 `{{OPENCODE_GLOBAL_ROOT}}` 替换为 `D:\custom\opencode`。

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
