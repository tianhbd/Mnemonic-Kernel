# Verification Checklist

## Repository Checks

- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1` successfully.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-index.ps1` successfully.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-boot.ps1` successfully.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-search.ps1 -Query "用户偏好"` and confirm it returns an entry when an index match exists.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 ...` against a temporary Root.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1 -Force` against a temporary Root.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-clean.ps1` successfully.

## Deployment Script Checks

- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1 -WhatIf` successfully.
- [ ] Confirm `deploy-opencode.ps1` exposes `-TargetRoot`, `-Backup`, `-DisableConflictingMemoryPlugin`, and `-WhatIf`.
- [ ] Confirm deployment creates `.backup\mnemonic-kernel-<timestamp>` before changing an existing target.
- [ ] Confirm deployment preserves existing `opencode.json` provider/model/mcp settings.
- [ ] Confirm deployment only removes matching `opencode-agent-memory` plugin entries.
- [ ] Confirm deployment preserves existing target memory entries, skill bodies, and active journal buffer files.

## OpenCode Global Verification

- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-opencode.ps1` successfully.
- [ ] Confirm global `AGENTS.md` exists.
- [ ] Confirm global `memory/index/default.md` exists and contains pointer metadata only.
- [ ] Confirm global `skills/skills.md` exists and remains an index only.
- [ ] Confirm `opencode-agent-memory` is absent from the global `opencode.json` plugin list.
- [ ] Run `opencode debug config` successfully.
- [ ] Run `opencode run --model llamacpp/27B --format default "只回答 ok"` successfully.

## Memory Rules

- [ ] Default loading reads only `memory/index/default.md`.
- [ ] Entry bodies are read only after index match.
- [ ] Query order is default, current-week, recent month indexes, year indexes, cold.
- [ ] Full `memory/` directory loading is forbidden as task context.
- [ ] Manual memory writes require a confirmed `[Memory Candidate]`.
- [ ] `scripts/journal-extract.ps1` is the only automatic durable-memory write path.

## Entry Schema

- [ ] Every entry has `id`, `created`, `updated`, `scope`, `type`, `status`, `risk`, `pinned`, `trigger`, `summary`, `content`, and `source`.
- [ ] Entry id follows `YYYYMMDD-HHmm-slug`.
- [ ] Entry path follows `memory/entries/YYYY-MM-DD/HHmm-slug.md`.
- [ ] Index files do not contain `content:` or `source:` body fields.

## Skills

- [ ] `skills/skills.md` is an index only.
- [ ] Default loading reads only `skills/skills.md`.
- [ ] Skill bodies are loaded only after triggers match.
- [ ] New skill creation requires a confirmed `[Skill Candidate]`.
- [ ] Journal extraction does not create skills automatically.
- [ ] Skill frontmatter includes `name`, `description`, `category`, and `triggers`.
- [ ] Promoted skills record `promoted_from_memory` metadata when created from memory.

## Journal

- [ ] Journal is not default context.
- [ ] `journal/buffer/current.md` and `journal/buffer/meta.json` exist.
- [ ] `journal/extracted/`, `journal/discarded/`, and `journal/reports/` exist.
- [ ] Journal only buffers recent turns and does not act as a long-term full log.
- [ ] Journal extraction either writes durable memory entries and reindexes, or writes only a discarded batch summary.
- [ ] When an existing skill covers the same task, `journal-extract.ps1` writes `reason: duplicated_by_skill` and `matched_skill`, and does not create memory.

## Promotion

- [ ] Create a test memory with `hit_count >= 5`.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1` and confirm `memory/review/skill-promote-candidates.md` is generated.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1 -Confirmed -MemoryId <id>`.
- [ ] Confirm the skill is created and indexed in `skills/skills.md`.
- [ ] Confirm the skill frontmatter contains `promoted_from_memory`.
- [ ] Confirm the original memory entry is permanently removed from `memory/entries/`.
- [ ] Confirm rebuilt memory indexes no longer reference the removed memory entry.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-maintain.ps1` and confirm `memory/review/promotable-memory.md` is generated.

## Security

- [ ] No API keys.
- [ ] No tokens.
- [ ] No sudo passwords.
- [ ] No private key bodies.
- [ ] `scripts/check.ps1` secret-pattern scan passes.
