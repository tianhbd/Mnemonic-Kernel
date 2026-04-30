# Memory / Skill / Journal Rules

id: 20260430-1900-memory-skill-journal-rules
created: 2026-04-30 19:00
updated: 2026-04-30 19:00
scope: project
type: mechanism
status: active
risk: low
pinned: true
hit_count: 0
last_hit:

trigger:
- memory rules
- skill rules
- journal rules
- Mnemonic Kernel rules

summary:
Detailed Mnemonic Kernel rules for memory, skills, journal, and pending fallback behavior.

content:
Memory stores verified reusable experience. Good memory candidates include long-term user preferences, stable project or environment facts, verified troubleshooting lessons, reusable command templates, and distilled journal patterns. Bad memory candidates include temporary facts, unverified guesses, one-off implementation details, and duplicate existing entries.

Skills store stable repeatable workflows. Creation requires the same workflow to recur, clear input/procedure/output/verification, stable reuse value, and more than a simple command or one-off action.

Journal stores raw process evidence. It is not default context, should be read only when explicitly requested, and distillation into memory or skills still requires candidate confirmation.

If a required persistence tool is unavailable, output a pending block instead of writing directly. Required pending fields are `status`, `reason`, `created_from`, and `next_action`.

source:
memory/memory-skill-journal-rules.md
