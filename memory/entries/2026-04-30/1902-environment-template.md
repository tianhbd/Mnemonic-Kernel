# Environment Facts Template

id: 20260430-1902-environment-template
created: 2026-04-30 19:02
updated: 2026-04-30 19:02
scope: project
type: environment
status: active
risk: low
pinned: false
hit_count: 0
last_hit:

trigger:
- environment
- project facts
- machine facts
- runtime constraints

summary:
Template for stable project, machine, workspace, or toolchain facts.

content:
Use this entry type for stable facts about a project, machine, workspace, or toolchain. Load when the user asks about environment-specific details or when a task requires machine paths, project structure, or known runtime constraints. Facts must be confirmed and include a last verified date.

source:
memory/environment.md
