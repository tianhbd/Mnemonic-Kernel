---
label: memory-compat-entrypoint
description: Compatibility entrypoint for the time-layered memory index
read_only: true
---

# Memory Compatibility Entrypoint

`memory/memory.md` is kept only for compatibility with older instructions and checks.

## Current Memory Entrypoints

- Default memory index: `memory/index/default.md`
- Master index directory: `memory/index/master.md`

## Rules

- Do not load `memory/entries/` by default.
- Do not scan the full `memory/` directory for task context.
- Use `scripts/memory-search.ps1` for memory lookup.
- Index files contain pointers only; entry bodies live under `memory/entries/`.
