# Mnemonic-Kernel Verification Checklist

## Repository Checks

- [ ] All scripts parse without syntax errors
- [ ] Scripts run with `-NoProfile -ExecutionPolicy Bypass`
- [ ] AGENTS.md is valid
- [ ] README.md is complete
- [ ] LICENSE file present
- [ ] CONTRIBUTING.md present

## Script Checks

- [ ] `check.ps1` - repository integrity verification
- [ ] `memory-boot.ps1` - boot memory index
- [ ] `memory-index.ps1` - rebuild memory index
- [ ] `memory-maintain.ps1` - maintain memory entries
- [ ] `memory-search.ps1` - search memory entries
- [ ] `journal-append.ps1` - append journal entries
- [ ] `journal-extract.ps1` - extract journal to memory
- [ ] `journal-clean.ps1` - clean journal archives
- [ ] `deploy-opencode.ps1` - deploy to OpenCode
- [ ] `verify-opencode.ps1` - verify OpenCode deployment
- [ ] `skill-promote.ps1` - promote memory to skill
- [ ] `new-memory.ps1` - create new memory
- [ ] `new-skill.ps1` - create new skill
