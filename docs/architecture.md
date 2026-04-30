# Architecture

Mnemonic Kernel separates persistent agent context into indexed memory, repeatable skills, and a short-term journal buffer that feeds memory extraction.

## Memory Layers

1. `memory/index/`: time-layered pointer indexes.
2. `memory/entries/`: durable memory bodies.
3. `memory/review/`: duplicate and conflict candidates requiring review.
4. `memory/reports/`: boot and maintenance reports.
5. `memory/memory.md`: compatibility pointer to the new index system.

## Journal Layers

1. `journal/buffer/`: active short-term interaction batch.
2. `journal/extracted/`: extracted batch summaries.
3. `journal/discarded/`: discarded batch summaries without full conversation bodies.
4. `journal/reports/`: latest extraction report.

## Memory Data Flow

```text
startup
  -> scripts/memory-boot.ps1
  -> validate index pointers
  -> rebuild memory/index/*.md
  -> load memory/index/default.md only

query
  -> default.md
  -> current-week.md
  -> month indexes
  -> year indexes
  -> cold.md
  -> matched entry body
```

## Journal Data Flow

```text
each completed turn
  -> scripts/journal-append.ps1
  -> update journal/buffer/current.md
  -> update journal/buffer/meta.json

when turn_count >= max_turns
  -> scripts/journal-extract.ps1
  -> decide extracted or discarded
  -> if extracted, write memory/entries/* and run scripts/memory-index.ps1
  -> reset journal/buffer/*
```

## Durable Write Flow

1. Draft a `[Memory Candidate]`.
2. Wait for explicit user confirmation.
3. Write the entry to `memory/entries/YYYY-MM-DD/HHmm-slug.md`.
4. Rebuild indexes with `scripts/memory-index.ps1`.
5. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1`.

Automatic exception:

- `scripts/journal-extract.ps1` may write to `memory/entries/` without a manual `[Memory Candidate]`.

## Anti-Bloat Strategy

- Load only `memory/index/default.md` by default.
- Read entry bodies only after an index match.
- Load only `skills/skills.md` by default.
- Load skill bodies only after a trigger match.
- Do not load journal by default.
- Keep full journal conversation bodies only in the active short-term buffer.
