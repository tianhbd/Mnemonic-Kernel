<div align="right">

[中文](#中文) | [English](#english)

</div>

## 中文

# Mnemonic Kernel

**Mnemonic Kernel** 是一套面向 AI Agent 的上下文、长期记忆、技能流程和交互缓冲治理骨架。

它解决的不是“记住更多”，而是“只保存值得保留的内容，并且只在需要时加载最小上下文”。

## 它到底在做什么

Mnemonic Kernel 把 Agent 的持久化上下文拆成 4 层：

```text
AGENTS.md  = 硬规则、索引入口、默认加载边界
memory     = 长期有效的事实、偏好、规则、排障经验
skills     = 可重复执行的稳定流程
journal    = 短期交互缓冲，作为 memory 的提炼来源
```

这 4 层的关键区别是：

- `AGENTS.md` 只放所有任务都必须知道的规则。
- `memory` 存长期有效内容，但默认只读索引，不读正文。
- `skills` 存稳定流程，但默认只读技能索引，不读具体 skill body。
- `journal` 只保留最近交互批次，不长期保留完整对话。

## 运行机制

系统运行时有 3 条主链路：

1. 启动链路
   `memory-boot.ps1` 校验索引指针、清理无效项、重建 memory 索引。
2. 查询链路
   Agent 先读 `memory/index/default.md`，只有命中索引才读取对应 entry 正文。
3. 提炼链路
   每轮交互先写入 `journal/buffer`，到阈值后再由 `journal-extract.ps1` 判断是否沉淀成 memory。

## 推荐目录结构

```text
Mnemonic Kernel/
├── AGENTS.md
├── README.md
├── memory/
│   ├── memory.md
│   ├── index/
│   │   ├── default.md
│   │   ├── current-week.md
│   │   ├── month-YYYY-MM.md
│   │   ├── year-YYYY.md
│   │   ├── cold.md
│   │   └── master.md
│   ├── entries/
│   │   └── YYYY-MM-DD/
│   │       └── HHmm-slug.md
│   ├── review/
│   └── reports/
├── skills/
│   ├── skills.md
│   └── example-skill/
├── journal/
│   ├── buffer/
│   │   ├── current.md
│   │   └── meta.json
│   ├── extracted/
│   ├── discarded/
│   ├── reports/
│   │   └── extract-report.md
│   └── README.md
├── templates/
├── scripts/
└── tests/
```

## Memory 机制

### 默认加载规则

- 启动后默认只加载 `memory/index/default.md`。
- `memory/index/*.md` 只保存指针和元数据，不保存正文。
- `memory/entries/` 只在索引命中后读取。
- 禁止默认读取 `memory/entries/`。
- 禁止全量扫描 `memory/`。

### 查询顺序

```text
default.md
  -> recent-3d
  -> hot
current-week.md
month indexes, newest to oldest
year indexes, newest to oldest
cold.md
matched memory entry
```

### Entry 标准格式

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
One-line durable summary.

content:
Full durable memory body.

source:
source note or journal path
```

## Journal 机制

### 定位

- `journal` 是短期交互缓冲，不是长期日志库。
- `journal` 默认不进上下文。
- `journal` 只服务于 memory 自动提炼。
- `journal` 不自动创建 skill。

### Buffer 写入

每轮交互结束后，宿主应调用 `scripts/journal-append.ps1`：

- 追加用户输入
- 追加助手摘要
- 追加关键操作和结果
- 更新 `journal/buffer/meta.json` 中的 `turn_count`

### 提炼逻辑

当 `turn_count >= max_turns` 时，调用 `scripts/journal-extract.ps1`：

- 若判断有长期价值，则直接生成 `memory/entries/...`
- 若无长期价值，则只写入 `journal/discarded/...`
- 无论哪种结果，最后都要重置活动 buffer

## 工作流程图

### 1. 启动与默认加载

```mermaid
flowchart TD
    A["Agent 启动"] --> B["运行 scripts/memory-boot.ps1"]
    B --> C["校验 memory/index 指针"]
    C --> D["清理无效项"]
    D --> E["重建 default / week / month / year / cold"]
    E --> F["默认只加载 memory/index/default.md"]
    F --> G["等待任务查询"]

    classDef boot fill:#dbeafe,stroke:#2563eb,color:#1e3a8a
    classDef index fill:#ede9fe,stroke:#7c3aed,color:#4c1d95
    classDef ready fill:#dcfce7,stroke:#16a34a,color:#14532d

    class A,B,C,D boot
    class E,F index
    class G ready
```

### 2. Memory 查询链路

```mermaid
flowchart TD
    A["收到任务"] --> B["读取 default.md"]
    B --> C{"recent-3d / hot 是否命中?"}
    C -- "是" --> D["读取对应 memory/entries 正文"]
    C -- "否" --> E["继续查 current-week"]
    E --> F{"是否命中?"}
    F -- "是" --> D
    F -- "否" --> G["继续查 month -> year -> cold"]
    G --> H{"是否命中?"}
    H -- "是" --> D
    H -- "否" --> I["不加载 memory 正文"]
    D --> J["执行任务"]
    I --> J

    classDef query fill:#fef3c7,stroke:#d97706,color:#78350f
    classDef entry fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef skip fill:#f3f4f6,stroke:#6b7280,color:#374151

    class A,B,E,G query
    class C,F,H query
    class D,J entry
    class I skip
```

### 3. Journal 提炼链路

```mermaid
flowchart TD
    A["每轮交互结束"] --> B["运行 journal-append.ps1"]
    B --> C["更新 current.md / meta.json"]
    C --> D{"turn_count >= max_turns ?"}
    D -- "否" --> E["结束，等待下一轮"]
    D -- "是" --> F["运行 journal-extract.ps1"]
    F --> G{"是否有 durable memory 价值?"}
    G -- "是" --> H["写入 memory/entries"]
    H --> I["运行 memory-index.ps1"]
    I --> J["写入 journal/extracted 摘要"]
    G -- "否" --> K["写入 journal/discarded 摘要"]
    J --> L["重置 current.md / meta.json"]
    K --> L
    L --> M["结束"]

    classDef journal fill:#fce7f3,stroke:#db2777,color:#831843
    classDef memory fill:#dbeafe,stroke:#2563eb,color:#1e3a8a
    classDef end fill:#dcfce7,stroke:#16a34a,color:#14532d

    class A,B,C,D,F,G journal
    class H,I,J,K,L memory
    class E,M end
```

## 常用脚本

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-boot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-index.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-search.ps1 -Query "用户偏好"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-maintain.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1 -Force
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-clean.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```

## 安全与边界

- 不保存 API key、token、sudo 密码、私钥正文。
- `journal` 写入前必须脱敏。
- `memory` 的手工写入仍然遵循确认规则。
- `journal-extract.ps1` 是唯一允许自动写入 memory 的路径。
- 发布前运行 `scripts/check.ps1`。

## English

# Mnemonic Kernel

**Mnemonic Kernel** is a governance skeleton for AI-agent context, durable memory, repeatable skills, and short-term interaction buffering.

The goal is not to remember more. The goal is to persist only what deserves to survive and load only the minimum context needed for the current task.

## What It Actually Does

Mnemonic Kernel splits persistent agent context into 4 layers:

```text
AGENTS.md  = hard rules, entrypoints, and default loading boundaries
memory     = durable facts, preferences, rules, and troubleshooting lessons
skills     = repeatable stable workflows
journal    = short-term interaction buffer that feeds memory extraction
```

The distinction is intentional:

- `AGENTS.md` stores rules every task must know.
- `memory` stores durable knowledge, but default loading is index-only.
- `skills` stores reusable workflows, but default loading is index-only.
- `journal` stores only recent interaction batches and is not a long-term conversation archive.

## Runtime Model

There are 3 main runtime paths:

1. Startup path
   `memory-boot.ps1` validates pointers, removes invalid references, and rebuilds memory indexes.
2. Query path
   The agent reads `memory/index/default.md` first and loads entry bodies only after an index hit.
3. Extraction path
   Each completed turn is appended into `journal/buffer`, and once the threshold is reached, `journal-extract.ps1` decides whether the batch should become durable memory.

## Recommended Layout

```text
Mnemonic Kernel/
├── AGENTS.md
├── README.md
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
├── templates/
├── scripts/
└── tests/
```

## Memory Mechanism

### Default Loading Rules

- Run `scripts/memory-boot.ps1` at startup.
- After boot, load only `memory/index/default.md` by default.
- `memory/index/*.md` stores pointers and metadata only, never entry bodies.
- Read `memory/entries/` only after an index match.
- Do not load `memory/entries/` by default.
- Do not scan the full `memory/` tree for task context.

### Query Order

```text
default.md
  -> recent-3d
  -> hot
current-week.md
month indexes, newest to oldest
year indexes, newest to oldest
cold.md
matched memory entry
```

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
One-line durable summary.

content:
Full durable memory body.

source:
source note or journal path
```

## Journal Mechanism

### Role

- `journal` is a short-term interaction buffer, not a long-term log store.
- `journal` is not default context.
- `journal` only serves automatic memory extraction.
- `journal` must not create skills automatically.

### Buffer Writes

After each completed interaction turn, the host should call `scripts/journal-append.ps1` to:

- append user input
- append assistant summary
- append key actions and results
- update `journal/buffer/meta.json`

### Extraction Logic

When `turn_count >= max_turns`, call `scripts/journal-extract.ps1`:

- if the batch has durable value, write new `memory/entries/...`
- if it does not, write only `journal/discarded/...`
- in both cases, reset the active buffer afterward

## Workflow Diagrams

### 1. Startup and Default Loading

```mermaid
flowchart TD
    A["Agent startup"] --> B["Run scripts/memory-boot.ps1"]
    B --> C["Validate memory/index pointers"]
    C --> D["Remove invalid references"]
    D --> E["Rebuild default / week / month / year / cold"]
    E --> F["Load only memory/index/default.md"]
    F --> G["Wait for task queries"]
```

### 2. Memory Query Path

```mermaid
flowchart TD
    A["Task arrives"] --> B["Read default.md"]
    B --> C{"Hit in recent-3d or hot?"}
    C -- "yes" --> D["Load matched memory entry body"]
    C -- "no" --> E["Check current-week"]
    E --> F{"Hit?"}
    F -- "yes" --> D
    F -- "no" --> G["Check month -> year -> cold"]
    G --> H{"Hit?"}
    H -- "yes" --> D
    H -- "no" --> I["Do not load memory body"]
    D --> J["Execute task"]
    I --> J
```

### 3. Journal Extraction Path

```mermaid
flowchart TD
    A["Completed turn"] --> B["Run journal-append.ps1"]
    B --> C["Update current.md / meta.json"]
    C --> D{"turn_count >= max_turns ?"}
    D -- "no" --> E["Stop and wait for next turn"]
    D -- "yes" --> F["Run journal-extract.ps1"]
    F --> G{"Durable memory value?"}
    G -- "yes" --> H["Write memory/entries"]
    H --> I["Run memory-index.ps1"]
    I --> J["Write journal/extracted summary"]
    G -- "no" --> K["Write journal/discarded summary"]
    J --> L["Reset current.md / meta.json"]
    K --> L
    L --> M["Done"]
```

## Common Scripts

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-boot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-index.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-search.ps1 -Query "user preference"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-maintain.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1 -Force
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-clean.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```

## Safety and Boundaries

- Do not store API keys, tokens, sudo passwords, or private key bodies.
- Redact sensitive content before writing to `journal`.
- Manual memory creation still follows confirmation rules.
- `journal-extract.ps1` is the only automatic memory-write path.
- Run `scripts/check.ps1` before publishing changes.
