# Verification Checklist

## Scripted Checks

- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-index.ps1` successfully.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-boot.ps1` successfully.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 ...` successfully.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1 -Force` successfully.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-clean.ps1` successfully.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1` successfully.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-search.ps1 -Query "用户偏好"` and confirm it returns an entry.

## Memory Structure

- [ ] `memory/index/default.md` exists.
- [ ] `memory/index/default.md` contains `recent-3d` and `hot`.
- [ ] `memory/index/current-week.md` exists.
- [ ] Current month and year index files exist.
- [ ] `memory/index/cold.md` exists.
- [ ] `memory/index/master.md` exists.
- [ ] `memory/entries/YYYY-MM-DD/HHmm-slug.md` stores entry bodies.
- [ ] `memory/memory.md` is only a compatibility pointer.

## Memory Rules

- [ ] Default loading reads only `memory/index/default.md`.
- [ ] Entry bodies are read only after index match.
- [ ] Query order is default, current-week, months, years, cold.
- [ ] Full memory directory loading is forbidden.
- [ ] New memory writes require a confirmed candidate before using `scripts/new-memory.ps1 -Confirmed`.

## Entry Schema

- [ ] Every entry has `id`, `created`, `updated`, `scope`, `type`, `status`, `risk`, `pinned`, `trigger`, `summary`, `content`, and `source`.
- [ ] Entry id follows `YYYYMMDD-HHmm-slug`.
- [ ] Entry path follows `memory/entries/YYYY-MM-DD/HHmm-slug.md`.

## Skills

- [ ] `skills/skills.md` is an index only.
- [ ] Default loading reads only `skills/skills.md`.
- [ ] Skill bodies are loaded only after triggers match.
- [ ] New skill creation requires a confirmed candidate before using `scripts/new-skill.ps1 -Confirmed`.

## Journal

- [ ] Journal is not default context.
- [ ] `journal/buffer/current.md` and `journal/buffer/meta.json` exist.
- [ ] `journal/extracted/`, `journal/discarded/`, and `journal/reports/` exist.
- [ ] `scripts/journal-append.ps1`, `scripts/journal-extract.ps1`, and `scripts/journal-clean.ps1` exist.
- [ ] Journal only buffers recent turns and does not act as a long-term full log.
- [ ] Journal extraction may auto-write durable memory entries and must update memory indexes.
- [ ] Journal must not create skills automatically.

## Security

- [ ] No API keys.
- [ ] No tokens.
- [ ] No sudo passwords.
- [ ] No private key contents.
