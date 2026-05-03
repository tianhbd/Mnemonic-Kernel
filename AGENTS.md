# Mnemonic Kernel Agent Rules

## Hard Rules

- `AGENTS.md` only stores hard rules, path indexes, and loading limits.
- Cases, pitfalls, command templates, and implementation details must live in `memory/entries/`, `skills/`, or `journal/`.
- Do not store API keys, tokens, sudo passwords, or private key contents.
- Use Chinese output by default when working with Chinese users; lead with conclusions.

## Index Entry Points

- Global config root: `{{OPENCODE_GLOBAL_ROOT}}`
- Global scripts root: `{{OPENCODE_GLOBAL_ROOT}}\scripts`
- When this file refers to Mnemonic Kernel scripts, use the global scripts root by default; do not guess from the current project directory.
- Example script invocation: `powershell -NoProfile -ExecutionPolicy Bypass -File {{OPENCODE_GLOBAL_ROOT}}\scripts\memory-boot.ps1`
- Default memory index: `memory/index/default.md`
- Memory master index: `memory/index/master.md`
- Legacy memory compatibility entrypoint: `memory/memory.md`
- Skills index: `skills/skills.md`
- Journal policy: `journal/README.md`
- Verification checklist: `tests/checklist.md`

## Memory Loading Rule

- Each conversation/session should run `{{OPENCODE_GLOBAL_ROOT}}\scripts\memory-boot.ps1` once before any memory use, after global `AGENTS.md` is loaded.
- In OpenCode Desktop, global `AGENTS.md` may be loaded on the first conversation rather than application startup; this is normal. Treat that first loaded conversation turn as the effective session boot point.
- Host-level hooks, shell wrappers, or Desktop launch wrappers may run `{{OPENCODE_GLOBAL_ROOT}}\scripts\memory-boot.ps1` earlier, but they are optional optimizations and must not be assumed in OpenCode Desktop.
- After boot, load only `memory/index/default.md` by default.
- `memory/index/*.md` stores only indexes and pointers, never memory bodies.
- `memory/entries/` stores memory bodies.
- Do not read `memory/entries/` by default.
- Never load or scan the full `memory/` directory for task context.
- If `memory/reports/boot-report.md` is missing, stale, or inconsistent, rerun `{{OPENCODE_GLOBAL_ROOT}}\scripts\memory-boot.ps1` before memory use.

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

- `{{OPENCODE_GLOBAL_ROOT}}\scripts\memory-boot.ps1` must validate all index pointers.
- Invalid pointers must be removed automatically.
- Low-risk duplicate memories may be merged only when facts are identical and safe.
- Conflicts, overwrites, version changes, user preference changes, and sensitive information must be written to `memory/review/`.

## Skills Loading Rules

- For all tasks, load only `skills/skills.md` by default.
- Load a skill body only when the task matches entries in `skills/skills.md`.
- Never load all skill bodies by default.

## Memory Scope Governance

- 所有 memory entries 必须包含 `scope` 字段，值为 `project` 或 `global`。
- Scope 判定优先级：显式输入 > 路径归属 > 关键词评分。
- 关键词评分差 >= 2 时自动判定 scope；否则标记 `scope_uncertain`，默认设为 `project`。
- 标记为 `scope_uncertain` 的记录需写入 `memory/review/scope-uncertain.md` 等待人工确认。
- `journal-extract.ps1` 负责 scope 自动检测；`new-memory.ps1` 依赖用户显式指定。
- Skill 晋升继承原 memory 的 scope，但允许手动覆盖。
- `skill-promote.ps1` 的 `-Scope` 参数可覆盖继承的 scope 值。
- `memory-maintain.ps1` 显示 promotion 候选时的 scope 信息。

## Journal Rule

- `journal` is the short-term interaction buffer, not a long-term log store.
- `journal` is not default context.
- `journal` only serves automatic memory extraction.
- `journal` must not create skills automatically.

## Journal Append Rule

- **Timing**: For each completed user-facing interaction turn, call `{{OPENCODE_GLOBAL_ROOT}}\scripts\journal-append.ps1` **before sending the final response** to the user. This is a before-final step, not a post-response action.
- **Scope**: Append applies only to user-facing turns (direct user queries and responses). It does NOT apply to internal system messages, background subagent-only events, or orchestrator-internal coordination that produces no user-facing output.
- `{{OPENCODE_GLOBAL_ROOT}}\scripts\journal-append.ps1` only appends the current user input, assistant summary, key actions, and results.
- **AssistantSummary**: The `AssistantSummary` parameter is the summary of the response **about to be sent** to the user, not a post-final retrospective action.
- **Threshold handling**: After `journal-append.ps1` completes, inspect its output. If `should_extract` is `True`, call `{{OPENCODE_GLOBAL_ROOT}}\scripts\journal-extract.ps1` **before** sending the final response.
- **Failure behavior**: A single failed `journal-append.ps1` attempt must NOT block the user response. Report the failure briefly in the final response and do NOT retry repeatedly. One attempt, one failure report, then continue.
- Do not write secret credential bodies into `journal`.

## Journal Extract Rule

- When `turn_count >= max_turns`, call `{{OPENCODE_GLOBAL_ROOT}}\scripts\journal-extract.ps1`.
- The Journal Append Rule's threshold handling will trigger `{{OPENCODE_GLOBAL_ROOT}}\scripts\journal-extract.ps1` automatically when `should_extract` is `True`.
- `{{OPENCODE_GLOBAL_ROOT}}\scripts\journal-extract.ps1` may write directly to `memory/entries/YYYY-MM-DD/` as the only exception to the manual memory confirmation rule.
- After journal extraction writes memory entries, it must call `{{OPENCODE_GLOBAL_ROOT}}\scripts\memory-index.ps1`.
- If the batch has no durable value, discard the buffer body and write only a discarded batch record.
- After extraction, reset `journal/buffer/current.md` and `journal/buffer/meta.json`.

## Journal Safety Rule

- Do not keep full conversations in `journal` long term.
- Do not store passwords, tokens, API keys, or private key bodies in `journal`.
- Do not write unverified guesses into `memory`.
- Do not create skills automatically from `journal`.

## Durable Write Rules

- Manual memory writes require a `[Memory Candidate]` and explicit user confirmation.
- `{{OPENCODE_GLOBAL_ROOT}}\scripts\journal-extract.ps1` is the only automatic memory write path.
- Skill creation requires a `[Skill Candidate]` and explicit user confirmation.
- Deduplicate before writing: check label, topic, trigger, and existing files.

## Candidate Lifecycle

```text
draft -> user confirmation -> accepted | revise | rejected
```

- `accepted`: write or create the durable artifact.
- `revise`: rewrite the full candidate and ask for confirmation again.
- `rejected`: discard; do not write.
