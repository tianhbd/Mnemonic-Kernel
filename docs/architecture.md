# Mnemonic Kernel Architecture

Mnemonic Kernel is a four-layer context governance structure for Agent hosts such as OpenCode.

```text
AGENTS.md
  hard rules, path indexes, loading boundaries

memory/
  durable facts, preferences, rules, mechanisms, and troubleshooting lessons

skills/
  reusable workflows loaded only after trigger match

journal/
  short-term interaction buffer used for memory extraction
```

## System Layers

| Layer | Purpose | Default Loading | Write Path |
|---|---|---|---|
| `AGENTS.md` | Hard rules, entrypoints, loading limits | Full file | Manual edits only |
| `memory` | Durable facts and lessons | Index only | Confirmed candidate or journal extraction |
| `skills` | Repeatable workflows | Index only | Confirmed skill candidate |
| `journal` | Short-term interaction buffer | Not loaded | Per-turn append, then extraction or discard |

`AGENTS.md` must stay small and stable. Cases, pitfalls, command templates, and implementation details belong in `memory/entries/`, `skills/`, `journal/`, or docs.

## Repository Layout

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

## Boot Path

```text
session start
  -> scripts/memory-boot.ps1
  -> validate memory/index pointers
  -> remove invalid pointers
  -> rebuild default / current-week / month / year / cold / master indexes
  -> write memory/reports/boot-report.md
  -> load memory/index/default.md only
```

`memory-boot.ps1` is allowed to scan `memory/entries/` because it is a maintenance script. Agents must not scan `memory/entries/` as default task context.

## Query Path

```text
task arrives
  -> read memory/index/default.md
  -> if no match, read memory/index/current-week.md
  -> if no match, read recent month indexes, newest to oldest
  -> if no match, read year indexes, newest to oldest
  -> if no match, read memory/index/cold.md
  -> load memory/entries/... body only after an index hit
```

`scripts/memory-search.ps1 -Query` implements this path and updates `hit_count` / `last_hit` for the matched entry before rebuilding indexes.

## Memory Index Strategy

| Index | Coverage | Notes |
|---|---|---|
| `default.md` / `recent-3d` | Updated in the last 3 days | Highest recency |
| `default.md` / `hot` | pinned, high-hit, or high-value types | Sorted by score |
| `current-week.md` | 3 to 10 days | Near-term context |
| `month-YYYY-MM.md` | 10 to 183 days | Recent history |
| `year-YYYY.md` | Older than 183 days | Long-tail history |
| `cold.md` | cold status or old unused entries | Last resort |

Index files contain pointer metadata only. Entry bodies live under `memory/entries/YYYY-MM-DD/HHmm-slug.md`.

## Memory Entry Schema

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

Supported high-value types include `user_preference`, `environment`, `project_rule`, `common_path`, `login_info`, `troubleshooting`, and `mechanism`.

## Journal Path

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

`journal` is not a long-term log store. It keeps only a short active buffer plus extracted/discarded summaries.

## Skills Path

`skills/skills.md` is the only default skill context. A skill body under `skills/{name}/SKILL.md` is loaded only when the task matches its trigger.

Skill creation requires a `[Skill Candidate]` and explicit confirmation. Journal extraction must not create skills automatically.

## Memory Promotion Path

```text
memory-search.ps1 updates hit_count
  -> memory-maintain.ps1 reports promotable-memory.md
  -> skill-promote.ps1 writes skill-promote-candidates.md
  -> user confirms one memory id
  -> new-skill.ps1 creates the skill with promoted_from_memory metadata
  -> original memory entry is permanently deleted
  -> memory-index.ps1 rebuilds indexes
```

Promotion is never automatic. `hit_count` is only a signal that a memory may now be stable enough to become a reusable skill.

## Journal Skill Suppression Path

```text
journal-extract.ps1
  -> classify durable candidates
  -> inspect skill index plus skill frontmatter
  -> if a stable skill already covers the same task
  -> write journal/discarded/... with reason duplicated_by_skill
  -> do not create new memory
```

This keeps `memory` as the fact and experience layer, and prevents stable workflows from flowing back out of `skills` into `memory`.

## Safety Boundaries

- Do not store API keys, tokens, sudo passwords, or private key bodies.
- Redact obvious secrets before writing journal content.
- Manual memory writes require confirmed candidates.
- `journal-extract.ps1` is the only automatic durable-memory write path.
- Full `memory/` and full `skills/` scans are maintenance operations, not task-context loading.
