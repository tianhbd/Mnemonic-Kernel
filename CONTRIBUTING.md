# Contributing to Mnemonic-Kernel

Thank you for your interest in contributing! We welcome contributions from the community.

## How to Contribute

1. **Fork the repository** to your GitHub account
2. **Create a new branch** for your feature or fix:
   ```powershell
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following the coding conventions below
4. **Test your changes** by running the verification script:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1
   ```
5. **Commit your changes** with a clear commit message:
   ```
   feat: add new memory search filter
   fix: resolve journal append encoding issue
   docs: update adapter documentation
   ```
6. **Push to your fork** and open a Pull Request

## Coding Conventions

- PowerShell scripts should use `-NoProfile -ExecutionPolicy Bypass` compatible syntax
- Follow existing script structure and comment style
- Add help comments (`<#...#>`) for all public functions
- Use `Write-Host` for user-facing output, `Write-Verbose` for debug info
- Keep scripts modular — one concern per script

## Pull Request Guidelines

- Keep PRs focused on a single concern
- Update related documentation (README, docs/) as needed
- Add or update tests in the `tests/` directory when applicable
- Reference any related issues in the PR description

## Code of Conduct

Please note that this project follows a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Questions?

Open a [discussion](https://github.com/tianhbd/Mnemonic-Kernel/discussions) or an [issue](https://github.com/tianhbd/Mnemonic-Kernel/issues/new/choose).
