# Mnemonic Kernel — Universal Memory Governance Framework + OpenCode Adapter

<div align="center">

![CI](https://img.shields.io/github/actions/workflow/status/tianhbd/Mnemonic-Kernel/ci.yml?branch=main&label=CI)
![License](https://img.shields.io/github/license/tianhbd/Mnemonic-Kernel?color=blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.4-blue?logo=powershell)
![Platform](https://img.shields.io/badge/platform-Windows-blue)
![GitHub last commit](https://img.shields.io/github/last-commit/tianhbd/Mnemonic-Kernel)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/tianhbd/Mnemonic-Kernel)

</div>

**Mnemonic Kernel** is a universal memory governance framework that separates durable rules, long-term memory, reusable workflows, and short-term interaction buffering into four layers: `AGENTS.md`, `memory`, `skills`, and `journal`. It is runtime-agnostic and connects to specific environments through an adapter layer.

The OpenCode adapter handles path injection, `AGENTS.md` rule enhancement, and the deploy mechanism, bridging the universal governance core into OpenCode's global configuration directory.

It does not try to remember more. It persists only durable content and loads only the minimum context required for the current task.

## Quick Start

```powershell
# Clone the repository
git clone https://github.com/tianhbd/Mnemonic-Kernel.git
cd Mnemonic-Kernel

# Run the verification check
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1

# Deploy to OpenCode (optional, requires OpenCode installed)
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1
```

See [Installation Guide](docs/installation.md) for system requirements and detailed setup.

## Core Model

### Dual-Mode Architecture

```text
┌──────────────────────────────────────────────────────────┐
│            Universal Memory Governance Framework          │
│                                                          │
│  AGENTS.md  = hard rules, entrypoints, loading boundaries│
│  memory     = durable facts, preferences, rules, lessons  │
│  skills     = repeatable stable workflows                 │
│  journal    = short-term interaction buffer for extraction│
│                                                          │
│  The governance core does not depend on any runtime       │
└───────────────────────┬──────────────────────────────────┘
                        │ adapter layer
                        ▼
              ┌─────────────────┐
              │  OpenCode Adapter│
              │                 │
              │  · path injection│
              │  · AGENTS.md     │
              │    enhancement   │
              │  · deploy        │
              │    mechanism     │
              └─────────────────┘
```

- Default loading is limited to `AGENTS.md`, `memory/index/default.md`, and `skills/skills.md`.
- `memory/index/*.md` contains pointers and metadata only; entry bodies are loaded only after an index match.
- `skills/skills.md` is an index only; skill bodies are loaded only after trigger matches.
- `journal` is not default context. It only feeds durable memory extraction.
- `journal-extract.ps1` is the only automatic durable-memory write path.

### Universal Governance Core

The four-layer structure remains consistent across any agent runtime:

| Layer | Responsibility | Loaded When |
|---|---|---|
| `AGENTS.md` | Hard rules, entrypoints, loading boundaries | Every session start |
| `memory/` | Durable facts, preferences, rules, experience | On-demand after index match |
| `skills/` | Reusable workflows, query templates, operating sequences | On-demand after trigger match |
| `journal/` | Short-term interaction buffer | Never in default context |

### OpenCode Adapter Layer

The adapter bridges the universal governance core into OpenCode runtime:

- **Path Injection**: Deploy scripts replace `{{OPENCODE_GLOBAL_ROOT}}` placeholders with actual paths (e.g. `C:\Users\simo\.config\opencode`)
- **AGENTS.md Enhancement**: Injects global path rules, Desktop loading timing, and Journal Append behavior refinement
- **Deploy Mechanism**: `deploy-opencode.ps1` creates backups, preserves existing configuration, and removes conflicting plugins

## Common Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-boot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-search.ps1 -Query "user preference"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1 -Force
```

## OpenCode Global Deployment

Deploy to the default OpenCode global directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1
```

Preview the deployment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1 -WhatIf
```

Verify the global runtime:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-opencode.ps1
```

The deployment target defaults to `C:\Users\simo\.config\opencode`. The script creates `.backup\mnemonic-kernel-<timestamp>` before mutation and preserves existing provider/model configuration in `opencode.json`. It only removes the known conflicting `opencode-agent-memory` plugin entry.

See `docs/opencode-global-deployment.md` for details.

## Documentation

- `docs/architecture.md`: architecture, runtime paths, data structures, and boundaries.
- `docs/opencode-global-deployment.md`: global deployment, backup, plugin conflict handling, and live validation.
- `tests/checklist.md`: repository and OpenCode global verification checklist.

## Memory -> Skill Promotion Path

- `memory` stores durable facts, preferences, environments, paths, troubleshooting lessons, and mechanisms.
- `skills` store stable reusable workflows, fixed query templates, output formats, and operating sequences.
- `hit_count` is only a promotion signal. It never triggers automatic promotion.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1` only writes promotion candidates to `memory/review/skill-promote-candidates.md`.
- Real promotion requires `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1 -Confirmed -MemoryId <id>`.
- Accounts, machines, IPs, login methods, and common paths may be promoted when they are hit frequently and have stable output patterns.

## Journal Skill Suppression

- `journal-extract.ps1` checks `skills/skills.md` plus `skills/*/SKILL.md` before writing new memory.
- If an existing skill already covers the same task, journal content is discarded instead of being written back into memory.
- The discarded batch records `reason: duplicated_by_skill` and `matched_skill`.
- This keeps `memory` focused on facts and experience that have not yet been solidified into skills.

## Promoted Memory Lifecycle

- Promotable entries first appear in `memory/review/promotable-memory.md` and `memory/review/skill-promote-candidates.md`.
- Confirmed promotion writes `promoted_from_memory` metadata into the created skill frontmatter.
- After promotion, the original memory entry is permanently deleted from `memory/entries/`.
- The memory index is rebuilt, and future journal batches for the same task are suppressed by the existing skill instead of creating new memory.

## Real Simulation Validation

The full promotion and suppression path has been executed in an isolated runtime simulation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-index.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\memory-maintain.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\skill-promote.ps1 -Confirmed -MemoryId <id>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-append.ps1 -MaxTurns 1 -UserText "<user>" -AssistantSummary "<assistant>" -Actions "<action>"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\journal-extract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```

Validated outcomes:

- `promotable-memory.md` reports high-hit memory as promotion candidates.
- `skill-promote-candidates.md` reports candidates without creating skills automatically.
- `-Confirmed -MemoryId <id>` creates the skill, writes `promoted_from_memory`, deletes the original memory entry, and rebuilds the memory index.
- Later journal extraction for the same task no longer creates memory and writes a discarded batch with `reason: duplicated_by_skill`.
- `scripts/check.ps1` validates that promoted memory is gone, indexes no longer reference deleted paths, and discarded records point to a real skill.

## Boundary

This framework is runtime-agnostic. The universal governance core operates independently, connecting to target environments through an adapter layer. An OpenCode adapter is currently provided.

This repository does not install OpenCode, configure providers or API keys, store tokens or private key bodies, or replace the agent runtime. It provides a controlled memory/journal/skill governance surface.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. Please note that this project follows a [Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE) © 2026 Haibo Tian
