# Installation Guide

## System Requirements

- **OS**: Windows 10/11, Windows Server 2019+
- **PowerShell**: 5.1 or 7.x (PowerShell Core)
- **Git**: Any recent version
- **Optional**: OpenCode runtime (for OpenCode adapter deployment)

## Quick Install

```powershell
# Clone the repository
git clone https://github.com/tianhbd/Mnemonic-Kernel.git
cd Mnemonic-Kernel

# Run integrity check
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1

# (Optional) Deploy to OpenCode
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-opencode.ps1
```

## Manual Setup

If you prefer a targeted deployment instead of the full repository:

1. Copy the `scripts/`, `memory/`, `skills/`, and `journal/` directories into your agent runtime workspace
2. Copy `AGENTS.md` to your agent's project root
3. Run `check.ps1` to verify the setup
4. Customize `AGENTS.md` rules for your specific agent runtime

## Verifying Installation

Run the check script to verify all components are correctly installed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
```

A successful check will report:
- All core directories exist
- Memory index is valid
- Skill index is valid
- Journal directory is writable

## Next Steps

- Read [Architecture Overview](architecture.md) to understand the framework
- Read [OpenCode Global Deployment](opencode-global-deployment.md) if using OpenCode
- Browse `templates/` for skill and memory templates
