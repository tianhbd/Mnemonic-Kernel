# Mnemonic Kernel Architecture

Mnemonic Kernel 是一个通用记忆治理框架，通过 `AGENTS.md`、`memory`、`skills`、`journal` 四层将长期规则、长期记忆、可复用流程和短期交互缓冲拆开。它不绑定任何特定 agent runtime，通过适配器层接入具体环境。

当前提供 OpenCode 适配器，将通用治理核接入 OpenCode 全局配置目录。

```text
┌──────────────────────────────────────────────────────────┐
│               通用记忆治理框架 (Governance Core)           │
│                                                          │
│  AGENTS.md  = 硬规则、入口、加载边界                       │
│  memory     = 长期事实、偏好、规则、排障经验                │
│  skills     = 可重复执行的稳定流程                         │
│  journal    = 短期交互缓冲，作为 memory 的提炼来源          │
│                                                          │
│  通用治理核不依赖任何特定 runtime                          │
└───────────────────────┬──────────────────────────────────┘
                        │ 适配器层
                        ▼
              ┌─────────────────┐
              │  OpenCode 适配器  │
              │                 │
              │  · 路径注入       │
              │  · AGENTS.md 增强 │
              │  · deploy 机制    │
              └─────────────────┘
```

## 概述 / Overview

Mnemonic Kernel 分为两部分：

- **通用记忆治理核心**：定义四层结构、加载策略、索引策略、scope 治理、candidate lifecycle、promotion pipeline。不依赖任何特定 runtime。
- **OpenCode 适配器**：薄层，负责路径注入、AGENTS.md 规则增强、deploy 脚本机制，将通用治理核接入 OpenCode 运行时。

默认加载最小上下文：`AGENTS.md`、`memory/index/default.md`、`skills/skills.md`。索引文件只保存指针和元数据，正文只在命中后读取。

English summary: The framework consists of a universal governance core (layered structure, loading strategy, indexing, scope governance, candidate lifecycle, promotion pipeline) and a thin OpenCode adapter (path injection, AGENTS.md enhancement, deploy mechanism). Default loading is minimal: index-only for memory and skills, body-on-demand.

---

## 通用记忆治理核心 / Universal Memory Governance Core

### 四层职责表

| 层 | 职责 | 默认加载 | 写入路径 |
|---|---|---|---|
| `AGENTS.md` | 硬规则、入口、加载边界 | 全文件 | 仅手动编辑 |
| `memory` | 长期事实、偏好、规则、经验 | 索引仅 | 确认的 candidate 或 journal 提取 |
| `skills` | 可复用流程、查询模板、操作顺序 | 索引仅 | 确认的 skill candidate |
| `journal` | 短期交互缓冲 | 不加载 | 每轮追加，然后提取或丢弃 |

`AGENTS.md` 必须保持精简和稳定。案例、陷阱、命令模板和实现细节应存入 `memory/entries/`、`skills/`、`journal/` 或 docs。

### 加载策略

- `AGENTS.md` 每次会话启动时全量加载。
- `memory/index/default.md` 启动时加载。索引命中后按需读取 `memory/entries/YYYY-MM-DD/HHmm-slug.md` 正文。
- `skills/skills.md` 启动时加载。trigger 匹配后按需读取 `skills/{name}/SKILL.md` 正文。
- `journal` 不进默认上下文，仅作为短期缓冲和自动提炼来源。

### 索引策略

| 索引 | 覆盖范围 | 说明 |
|---|---|---|
| `default.md` / `recent-3d` | 最近 3 天更新 | 最高时效性 |
| `default.md` / `hot` | pinned、高命中或高价值类型 | 按分数排序 |
| `current-week.md` | 3 到 10 天 | 近期上下文 |
| `month-YYYY-MM.md` | 10 到 183 天 | 近期历史 |
| `year-YYYY.md` | 183 天以上 | 长尾历史 |
| `cold.md` | cold 状态或旧未使用条目 | 最后手段 |

索引文件只包含指针元数据。Entry 正文位于 `memory/entries/YYYY-MM-DD/HHmm-slug.md`。

### Entry Schema

```text
# Title

id: YYYYMMDD-HHmm-slug
created: YYYY-MM-DD HH:mm
updated: YYYY-MM-DD HH:mm
scope: project
type: troubleshooting
status: active
risk: low
pinned: false
hit_count: 0
last_hit:

trigger:
- keyword

summary:
一行持久化摘要。

content:
完整记忆正文。

source:
来源笔记或 journal 路径
```

支持的高价值类型包括 `user_preference`、`environment`、`project_rule`、`common_path`、`login_info`、`troubleshooting` 和 `mechanism`。

---

## 通用记忆治理机制 / Universal Memory Governance Mechanisms

### Boot Path

```text
session start
  -> scripts/memory-boot.ps1
  -> validate memory/index pointers
  -> remove invalid pointers
  -> rebuild default / current-week / month / year / cold / master indexes
  -> write memory/reports/boot-report.md
  -> load memory/index/default.md only
```

`memory-boot.ps1` 作为维护脚本可以扫描 `memory/entries/`。Agent 不得将 `memory/entries/` 作为默认任务上下文扫描。

### Query Path

```text
task arrives
  -> read memory/index/default.md
  -> if no match, read memory/index/current-week.md
  -> if no match, read recent month indexes, newest to oldest
  -> if no match, read year indexes, newest to oldest
  -> if no match, read memory/index/cold.md
  -> load memory/entries/... body only after an index hit
```

`scripts/memory-search.ps1 -Query` 实现此路径，并在重建索引前更新命中条目的 `hit_count` 和 `last_hit`。

### Journal Path

```text
completed turn
  -> scripts/journal-append.ps1
  -> redact obvious secrets
  -> append user text, assistant summary, actions
  -> increment journal/buffer/meta.json turn_count
  -> if turn_count >= max_turns, run scripts/journal-extract.ps1
  -> extract durable memory entries or write a discarded batch record
  -> reset journal/buffer/current.md and meta.json
```

`journal` 不是长期日志存储。它只保留短期活动缓冲和提取或丢弃的摘要。

### Memory Promotion Path

```text
memory-search.ps1 updates hit_count
  -> memory-maintain.ps1 reports promotable-memory.md
  -> skill-promote.ps1 writes skill-promote-candidates.md
  -> user confirms one memory id
  -> new-skill.ps1 creates the skill with promoted_from_memory metadata
  -> original memory entry is permanently deleted
  -> memory-index.ps1 rebuilds indexes
```

晋升从不自动发生。`hit_count` 仅作为信号，表明某条 memory 可能已足够稳定，可以成为可复用的 skill。

### Journal Skill Suppression Path

```text
journal-extract.ps1
  -> classify durable candidates
  -> inspect skill index plus skill frontmatter
  -> if a stable skill already covers the same task
  -> write journal/discarded/... with reason duplicated_by_skill
  -> do not create new memory
```

这确保 `memory` 只保存事实和经验层数据，防止已固化的流程从 `skills` 回流到 `memory`。

---

## Scope Governance / Scope 治理

所有 memory entries 必须包含 `scope` 字段，值为 `project` 或 `global`。

### 判定优先级

1. **显式输入**：用户在创建 memory 时直接指定 scope
2. **路径归属**：根据条目内容关联的路径判断（项目路径 vs 全局路径）
3. **关键词评分**：对项目关键词和全局关键词分别评分

### scope_uncertain 处理

关键词评分差 >= 2 时自动判定 scope；否则标记为 `scope_uncertain`，默认设为 `project`。

标记为 `scope_uncertain` 的记录需写入 `memory/review/scope-uncertain.md` 等待人工确认。

### 工具分工

- `journal-extract.ps1` 负责 scope 自动检测。
- `new-memory.ps1` 依赖用户显式指定。

### Skill Promotion Scope 继承

Skill 晋升继承原 memory 的 scope，但允许手动覆盖。`skill-promote.ps1` 的 `-Scope` 参数可覆盖继承的 scope 值。`memory-maintain.ps1` 显示 promotion 候选时的 scope 信息。

English summary: Every memory entry carries a `scope` field (`project` or `global`). Determination follows explicit input, path attribution, then keyword scoring. Entries with ambiguous scope are marked `scope_uncertain`, default to `project`, and written to `memory/review/scope-uncertain.md`. Skill promotion inherits the source memory scope with manual override available.

---

## Candidate Lifecycle / 候选生命周期

所有手动 memory 写入和 skill 创建必须经过候选生命周期。

```text
draft -> user confirmation -> accepted | revise | rejected
```

- **accepted**：写入或创建持久化 artifacts。
- **revise**：重写完整候选，重新请求确认。
- **rejected**：丢弃，不写入。

### 具体规则

- 手动 memory 写入需要一个 `[Memory Candidate]` 和用户明确确认。
- `journal-extract.ps1` 是唯一允许自动写入 durable memory 的路径。
- Skill 创建需要一个 `[Skill Candidate]` 和用户明确确认。
- 写入前进行去重：检查 label、topic、trigger 和现有文件。
- `journal-extract.ps1` 不得自动创建 skills。

---

## OpenCode 适配器 / OpenCode Adapter

适配器层将通用治理核接入 OpenCode 运行时，负责三件事：路径注入、AGENTS.md 增强、deploy 机制。

### 路径注入机制

项目版 AGENTS.md 使用 `{{OPENCODE_GLOBAL_ROOT}}` 占位符和相对路径。deploy 脚本在部署时将占位符替换为实际的运行时路径。

例如：
- 项目 AGENTS.md 中：`{{OPENCODE_GLOBAL_ROOT}}`
- 部署后全局 AGENTS.md 中：`C:\Users\simo\.config\opencode`

这确保通用核保持 runtime-agnostic，同时部署后在目标环境中路径正确。

### AGENTS.md 增强

全局版 AGENTS.md 在项目版基础上增加以下运行时增强（属于适配器层，不属于通用核）：

1. **全局路径索引**：定义全局根目录（`C:\Users\simo\.config\opencode`）和全局脚本根目录，明确脚本调用路径。
2. **OpenCode Desktop 加载时序说明**：AGENTS.md 可能在应用启动后的第一轮对话才加载，而非应用启动时立即加载。这影响 boot 脚本的执行时机。
3. **Journal Append 细化**：
   - **Timing**：before-final，在发送最终回复之前调用，不是事后行为。
   - **Scope**：仅用户交互轮次，不包括内部系统消息或后台 subagent 事件。
   - **AssistantSummary 语义**：即将发送的回复摘要，不是事后回顾。
   - **Threshold handling**：检测 `should_extract` 为 `True` 时自动触发 `journal-extract.ps1`。
   - **Failure behavior**：单次失败不阻塞用户回复，报告一次后继续。
4. **脚本调用绝对路径**：部署后的 AGENTS.md 使用完整绝对路径调用脚本，确保无论工作目录如何都能正确执行。

### Deploy 脚本机制

`deploy-opencode.ps1` 负责将 Mnemonic Kernel 部署到 OpenCode 全局配置目录：

- **目标目录**：默认为 `C:\Users\simo\.config\opencode`，支持 `-OpenCodeRoot` 参数覆盖。
- **备份机制**：部署前创建 `.backup\mnemonic-kernel-<timestamp>` 备份。
- **路径注入**：将 AGENTS.md 中的 `{{OPENCODE_GLOBAL_ROOT}}` 占位符替换为目标路径。
- **配置保留**：保留 `opencode.json` 中的 provider/model 配置。
- **冲突处理**：移除已知冲突的 `opencode-agent-memory` 插件入口。
- **预览模式**：`-WhatIf` 参数可预览所有操作而不实际执行。

`verify-opencode.ps1` 提供部署后的验证，包括路径注入验证（检查部署后 AGENTS.md 不含未替换的占位符）和叙事一致性检查。

English summary: The OpenCode adapter bridges the governance core to the OpenCode runtime through path injection (replacing `{{OPENCODE_GLOBAL_ROOT}}` placeholders), AGENTS.md enhancement (global path rules, Desktop loading timing, Journal Append refinement, absolute script paths), and a deploy mechanism (backup, preserve config, remove conflicts, preview with `-WhatIf`).

---

## 安全边界 / Safety Boundaries

- 不要存储 API keys、tokens、sudo 密码或私钥正文。
- 写入 journal 内容前脱敏明显的密钥。
- 手动 memory 写入需要确认的 candidate。
- `journal-extract.ps1` 是唯一自动写入 durable memory 的路径。
- 全量 `memory/` 和全量 `skills/` 扫描是维护操作，不是任务上下文加载。
- 不要将未验证的猜测写入 `memory`。
- 不要从 `journal` 自动创建 skills。
- 不要长期保留 `journal` 中的完整对话。

---

## 仓库布局 / Repository Layout

```text
Mnemonic Kernel/
├── AGENTS.md
├── README.md
├── docs/
│   ├── architecture.md
│   └── opencode-global-deployment.md
├── memory/
│   ├── memory.md
│   ├── index/
│   ├── entries/
│   ├── review/
│   └── reports/
├── skills/
│   ├── skills.md
│   └── example-skill/
├── journal/
│   ├── buffer/
│   ├── extracted/
│   ├── discarded/
│   ├── reports/
│   └── README.md
├── scripts/
├── templates/
└── tests/
```
