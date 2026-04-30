<div align="right">

[中文](#中文) | [English](#english)

</div>

## 中文

# Journal Subsystem

`journal` 是 Mnemonic Kernel 的短期交互缓冲区。

它不是长期日志库，也不是默认上下文。

## 作用

- 缓冲最近几轮交互。
- 为自动 memory 提炼提供原始材料。
- 避免长期保存完整对话。
- 禁止自动创建 skill。

## 目录结构

```text
journal/
├── buffer/
│   ├── current.md
│   └── meta.json
├── extracted/
├── discarded/
└── reports/
    └── extract-report.md
```

## 规则

- `journal` 默认不加载。
- `journal` 只保存最近交互批次。
- `journal` 不得保存密码、token、API key、私钥正文。
- `journal-extract.ps1` 可以直接写入 `memory/entries/`，这是手工 memory 确认规则的唯一例外。
- `journal` 不得自动创建 skill。
- 提炼后必须清空或重置活动 buffer。

## English

# Journal Subsystem

`journal` is the short-term interaction buffer of Mnemonic Kernel.

It is not a long-term log store and it is not default context.

## Purpose

- Buffer the most recent conversation turns.
- Provide source material for automatic memory extraction.
- Avoid long-term storage of full conversations.
- Avoid any automatic skill creation.

## Directory Layout

```text
journal/
├── buffer/
│   ├── current.md
│   └── meta.json
├── extracted/
├── discarded/
└── reports/
    └── extract-report.md
```

## Rules

- `journal` is not loaded by default.
- `journal` stores recent interaction batches only.
- `journal` must not store passwords, tokens, API keys, or private key bodies.
- `journal-extract.ps1` may write directly to `memory/entries/` as the only exception to the normal manual memory confirmation rule.
- `journal` must not create skills automatically.
- After extraction, the active buffer must be cleared or reset.
