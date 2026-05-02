<div align="right">

[中文](#中文) | [English](#english)

</div>

## 中文

# Mnemonic Kernel

**Mnemonic Kernel** 是面向 AI Agent 的上下文治理骨架，用 `AGENTS.md`、`memory`、`skills`、`journal` 四层把长期规则、长期记忆、可复用流程和短期交互缓冲拆开。

它的目标不是“让 Agent 记住更多”，而是“只保存值得保留的内容，并且只在任务需要时加载最小上下文”。

## 核心机制

```text
AGENTS.md  = 硬规则、入口、加载边界
memory     = 长期事实、偏好、规则、排障经验
skills     = 可重复执行的稳定流程
journal    = 短期交互缓冲，作为 memory 的提炼来源
```

- 默认只加载 `AGENTS.md`、`memory/index/default.md`、`skills/skills.md`。
- `memory/index/*.md` 只保存指针和元数据，正文只在索引命中后读取。
- `skills/skills.md` 只是索引，具体 skill body 只在 trigger 命中后读取。
- `journal` 默认不进上下文，只作为短期缓冲和 memory 自动提炼来源。
- `journal-extract.ps1` 是唯一允许自动写入 durable memory 的路径。

## 常用命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-boot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-search.ps1 -Query "用户偏好"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1 -Force
```

## OpenCode 全局部署

部署到默认 OpenCode 全局目录：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1
```

只查看将要执行的操作：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1 -WhatIf
```

实机验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-opencode.ps1
```

部署脚本默认目标为 `C:\Users\simo\.config\opencode`，会先创建 `.backup\mnemonic-kernel-<timestamp>`，并保留既有 `opencode.json` 中的 provider/model 配置。它只会移除已知冲突的 `opencode-agent-memory` 插件入口。

详细部署说明见 `docs/opencode-global-deployment.md`。

## 文档入口

- `docs/architecture.md`：四层架构、运行链路、数据结构和边界。
- `docs/opencode-global-deployment.md`：全局部署、备份、插件冲突和实机验证。
- `tests/checklist.md`：仓库级验证和 OpenCode 全局验证清单。

## Memory -> Skill Promotion Path

- `memory` 保存事实、偏好、环境、路径、排障经验和机制性知识。
- `skills` 保存稳定、可复用、可执行的流程，以及固定的查询模板、输出格式和操作顺序。
- `hit_count` 只用于触发候选，不会自动把 memory 晋升为 skill。
- 运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1` 只会生成 `memory/review/skill-promote-candidates.md`。
- 真正晋升必须显式执行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1 -Confirmed -MemoryId <id>`。
- 账号、机器、IP、登录方式、常用路径信息，只要命中频繁且输出格式固定，也可以晋升为 skill。

## Journal Skill Suppression

- `journal-extract.ps1` 在写入 memory 前会检查现有 `skills/skills.md` 和 `skills/*/SKILL.md`。
- 如果同类任务已经被 skill 覆盖，journal 不再回流为 memory。
- 这类批次会写入 `journal/discarded/`，并标记 `reason: duplicated_by_skill` 与 `matched_skill`。
- 这保证 memory 只保存尚未固化为 skill 的事实和经验层信息。

## Promoted Memory Lifecycle

- 可晋升 memory 会先出现在 `memory/review/promotable-memory.md` 和 `memory/review/skill-promote-candidates.md`。
- 确认晋升后，`new-skill.ps1` 会在 skill frontmatter 中写入 `promoted_from_memory` 来源信息。
- 晋升成功后，原 memory 会从 `memory/entries/` 永久删除，不进入 archive。
- 删除后会重建 memory index，后续 journal 再遇到同类任务时会被 skill 抑制，不再生成新的 memory。

## Real Simulation Validation

下面这条链路已经按独立临时环境完整跑通过：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-index.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-maintain.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1 -Confirmed -MemoryId <id>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -MaxTurns 1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```

验证点：

- `promotable-memory.md` 能发现高命中 memory。
- `skill-promote-candidates.md` 能生成候选，不会自动创建 skill。
- `-Confirmed -MemoryId <id>` 会创建 skill、写入 `promoted_from_memory`、删除原 memory、并重建 memory index。
- 后续同类 journal 提炼不会再生成 memory，而是写入 `journal/discarded/` 并标记 `reason: duplicated_by_skill`。
- `scripts/check.ps1` 会校验已晋升 memory 不再残留、索引不再引用旧路径、discarded 记录指向真实 skill。

## 边界

本仓库不负责安装 OpenCode、不配置 provider/API key、不保存 token 或私钥正文，也不替代 agent runtime。它只提供受控的 memory/journal/skill 治理面。

## English

# Mnemonic Kernel

**Mnemonic Kernel** is a governance skeleton for AI-agent context, durable memory, reusable skills, and short-term interaction buffering.

It does not try to remember more. It persists only durable content and loads only the minimum context required for the current task.

## Core Model

```text
AGENTS.md  = hard rules, entrypoints, loading boundaries
memory     = durable facts, preferences, rules, troubleshooting lessons
skills     = repeatable stable workflows
journal    = short-term interaction buffer used for memory extraction
```

- Default loading is limited to `AGENTS.md`, `memory/index/default.md`, and `skills/skills.md`.
- `memory/index/*.md` contains pointers and metadata only; entry bodies are loaded only after an index match.
- `skills/skills.md` is an index only; skill bodies are loaded only after trigger matches.
- `journal` is not default context. It only feeds durable memory extraction.
- `journal-extract.ps1` is the only automatic durable-memory write path.

## Common Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-boot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-search.ps1 -Query "user preference"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1 -Force
```

## OpenCode Global Deployment

Deploy to the default OpenCode global directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1
```

Preview the deployment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1 -WhatIf
```

Verify the global runtime:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-opencode.ps1
```

The deployment target defaults to `C:\Users\simo\.config\opencode`. The script creates `.backup\mnemonic-kernel-<timestamp>` before mutation and preserves existing provider/model configuration in `opencode.json`. It only removes the known conflicting `opencode-agent-memory` plugin entry.

See `docs/opencode-global-deployment.md` for details.

## Documentation

- `docs/architecture.md`: architecture, runtime paths, data structures, and boundaries.
- `docs/opencode-global-deployment.md`: global deployment, backup, plugin conflict handling, and live validation.
- `tests/checklist.md`: repository and OpenCode global verification checklist.

## Memory -> Skill Promotion Path

- `memory` stores durable facts, preferences, environments, paths, troubleshooting lessons, and mechanisms.
- `skills` store stable reusable workflows, fixed query templates, output formats, and operating sequences.
- `hit_count` is only a promotion signal. It never triggers automatic promotion.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1` only writes promotion candidates to `memory/review/skill-promote-candidates.md`.
- Real promotion requires `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1 -Confirmed -MemoryId <id>`.
- Accounts, machines, IPs, login methods, and common paths may be promoted when they are hit frequently and have stable output patterns.

## Journal Skill Suppression

- `journal-extract.ps1` checks `skills/skills.md` plus `skills/*/SKILL.md` before writing new memory.
- If an existing skill already covers the same task, journal content is discarded instead of being written back into memory.
- The discarded batch records `reason: duplicated_by_skill` and `matched_skill`.
- This keeps `memory` focused on facts and experience that have not yet been solidified into skills.

## Promoted Memory Lifecycle

- Promotable entries first appear in `memory/review/promotable-memory.md` and `memory/review/skill-promote-candidates.md`.
- Confirmed promotion writes `promoted_from_memory` metadata into the created skill frontmatter.
- After promotion, the original memory entry is permanently deleted from `memory/entries/`.
- The memory index is rebuilt, and future journal batches for the same task are suppressed by the existing skill instead of creating new memory.

## Real Simulation Validation

The full promotion and suppression path has been executed in an isolated runtime simulation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-index.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-maintain.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1 -Confirmed -MemoryId <id>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -MaxTurns 1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```

Validated outcomes:

- `promotable-memory.md` reports high-hit memory as promotion candidates.
- `skill-promote-candidates.md` reports candidates without creating skills automatically.
- `-Confirmed -MemoryId <id>` creates the skill, writes `promoted_from_memory`, deletes the original memory entry, and rebuilds the memory index.
- Later journal extraction for the same task no longer creates memory and writes a discarded batch with `reason: duplicated_by_skill`.
- `scripts/check.ps1` validates that promoted memory is gone, indexes no longer reference deleted paths, and discarded records point to a real skill.

## Boundary

This repository does not install OpenCode, configure providers or API keys, store tokens or private key bodies, or replace the agent runtime. It provides a controlled memory/journal/skill governance surface.
