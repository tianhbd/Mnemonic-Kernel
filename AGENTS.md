# Mnemonic Kernel Agent Rules

## Hard Rules

- `AGENTS.md` only stores hard rules, path indexes, and loading limits.
- Cases, pitfalls, command templates, and implementation details must live in `memory/entries/`, `skills/`, or `journal/`.
- Do not store API keys, tokens, sudo passwords, or private key contents.
- Use Chinese output by default when working with Chinese users; lead with conclusions.

## Index Entry Points

- Default memory index: `memory/index/default.md`
- Memory master index: `memory/index/master.md`
- Legacy memory compatibility entrypoint: `memory/memory.md`
- Skills index: `skills/skills.md`
- Journal policy: `journal/README.md`
- Verification checklist: `tests/checklist.md`

## Memory Loading Rule

- At startup, run `scripts/memory-boot.ps1`.
- After boot, load only `memory/index/default.md` by default.
- `memory/index/*.md` stores only indexes and pointers, never memory bodies.
- `memory/entries/` stores memory bodies.
- Do not read `memory/entries/` by default.
- Never load or scan the full `memory/` directory for task context.

## Memory Search Rule

- Query memory from near to far in this fixed order:
  1. `memory/index/default.md`
  2. `memory/index/current-week.md`
  3. Recent 6 month indexes, newest to oldest
  4. Year indexes, newest to oldest
  5. `memory/index/cold.md`
- Read an entry body only after an index match.
- Do not skip near indexes and jump directly to old indexes.

## Memory Maintenance Rule

- `scripts/memory-boot.ps1` must validate all index pointers.
- Invalid pointers must be removed automatically.
- Low-risk duplicate memories may be merged only when facts are identical and safe.
- Conflicts, overwrites, version changes, user preference changes, and sensitive information must be written to `memory/review/`.

## Skills Loading Rules

- For all tasks, load only `skills/skills.md` by default.
- Load a skill body only when the task matches entries in `skills/skills.md`.
- Never load all skill bodies by default.

## Journal Rule

- `journal` is the short-term interaction buffer, not a long-term log store.
- `journal` is not default context.
- `journal` only serves automatic memory extraction.
- `journal` must not create skills automatically.

## Journal Append Rule

- Each completed interaction turn should call `scripts/journal-append.ps1`.
- `journal-append.ps1` only appends the current user input, assistant summary, key actions, and results.
- Do not write secret credential bodies into `journal`.

## Journal Extract Rule

- When `turn_count >= max_turns`, call `scripts/journal-extract.ps1`.
- `scripts/journal-extract.ps1` may write directly to `memory/entries/YYYY-MM-DD/` as the only exception to the manual memory confirmation rule.
- After journal extraction writes memory entries, it must call `scripts/memory-index.ps1`.
- If the batch has no durable value, discard the buffer body and write only a discarded batch record.
- After extraction, reset `journal/buffer/current.md` and `journal/buffer/meta.json`.

## Journal Safety Rule

- Do not keep full conversations in `journal` long term.
- Do not store passwords, tokens, API keys, or private key bodies in `journal`.
- Do not write unverified guesses into `memory`.
- Do not create skills automatically from `journal`.

## Durable Write Rules

- Manual memory writes require a `[Memory Candidate]` and explicit user confirmation.
- `scripts/journal-extract.ps1` is the only automatic memory write path.
- Skill creation requires a `[Skill Candidate]` and explicit user confirmation.
- Deduplicate before writing: check label, topic, trigger, and existing files.

## Candidate Lifecycle

```text
draft -> user confirmation -> accepted | revise | rejected
```

- `accepted`: write or create the durable artifact.
- `revise`: rewrite the full candidate and ask for confirmation again.
- `rejected`: discard; do not write.
