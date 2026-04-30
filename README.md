<div align="right">

[中文](#中文) | [English](#english)

</div>

## 中文

# Mnemonic Kernel

**Mnemonic Kernel** 是一套面向 AI Agent 的上下文、长期记忆、技能流程和过程日志治理机制。

目标不是让 Agent 记住一切，而是让 Agent 只在正确的位置保存正确的信息，并通过索引按需加载。

## 核心结构

```text
AGENTS.md  = 硬规则 / 索引入口 / 加载限制
memory     = 时间分层索引 + entries 正文库
skills     = 可重复执行的稳定流程
journal    = 短期交互缓冲 + memory 提炼来源
```

## 推荐目录结构

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

## Memory 规则

- 启动时运行 `scripts/memory-boot.ps1`。
- boot 完成后默认只加载 `memory/index/default.md`。
- `memory/index/*.md` 只保存索引和指针，不保存正文。
- `memory/entries/` 只在索引命中后读取。
- 禁止默认读取 `memory/entries/`。
- 禁止全量读取 `memory/`。

## Journal 规则

- `journal` 只保存最近 N 轮交互的短期缓冲，不作为长期日志库。
- `journal` 默认不加载进上下文。
- `journal` 只服务于 `memory` 自动提炼，不负责 skill 创建。
- 满足阈值后由 `scripts/journal-extract.ps1` 自动判断是否值得沉淀为 `memory/entries/`。
- 提炼完成后必须清空或重置活动 buffer。

## 常用脚本

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-boot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-index.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-search.ps1 -Query "用户偏好"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1 -Force
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-clean.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```

## 安全规则

- 不保存 API key、token、sudo 密码、私钥内容。
- journal 中涉及敏感信息时必须脱敏。
- 写入或发布前运行 `scripts/check.ps1`。

## English

# Mnemonic Kernel

**Mnemonic Kernel** is a context, long-term memory, skill, and process-log governance skeleton for AI agents.

The goal is not to make an agent remember everything. The goal is to store the right information in the right place and load it through indexes only when needed.

## Core Structure

```text
AGENTS.md  = hard rules / entrypoints / loading limits
memory     = time-layered indexes + durable entry bodies
skills     = repeatable stable workflows
journal    = short-term interaction buffer + memory extraction source
```

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

## Memory Rules

- Run `scripts/memory-boot.ps1` at startup.
- After boot, load only `memory/index/default.md` by default.
- `memory/index/*.md` stores pointers and metadata only, never entry bodies.
- Read `memory/entries/` only after an index match.
- Do not load `memory/entries/` by default.
- Do not scan the full `memory/` tree for task context.

## Journal Rules

- `journal` is a short-term interaction buffer, not a long-term log store.
- `journal` is not default context.
- `journal` only serves automatic memory extraction and must not create skills.
- `scripts/journal-extract.ps1` decides whether a batch should be distilled into `memory/entries/`.
- After extraction, the active buffer must be cleared or reset.

## Common Scripts

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-boot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-index.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-search.ps1 -Query "user preference"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1 -Force
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-clean.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```

## Security Rules

- Do not store API keys, tokens, sudo passwords, or private key bodies.
- Redact sensitive content before writing to `journal`.
- Run `scripts/check.ps1` before publishing changes.
