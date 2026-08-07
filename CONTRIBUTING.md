# Contributing to ProfMig

First of all, thank you for taking the time to contribute to ProfMig.

ProfMig is an open-source PowerShell toolkit focused on reliable Windows user profile migration. Contributions that improve reliability, maintainability, documentation, testing or usability are always welcome.

---

## Ways to contribute

You can contribute by:

- Reporting bugs
- Suggesting new features
- Improving documentation
- Improving PowerShell code quality
- Creating or improving tests
- Reviewing pull requests

---

## Development guidelines

Please follow these guidelines when contributing.

### General

- Keep functions small and focused.
- Use descriptive function and variable names.
- Add comments only where they improve readability.
- Avoid duplicate code.
- Keep modules independent whenever possible.

### PowerShell

- Target Windows PowerShell 5.1 compatibility unless otherwise discussed.
- Follow approved PowerShell verb naming conventions.
- Use `Write-Verbose` where appropriate.
- Use structured error handling (`try/catch`) when required.
- Do not use global variables unless absolutely necessary.

### Formatting

- Use four spaces for indentation.
- Save files as UTF-8.
- Keep line length reasonable where practical.

---

## Pull Requests

Before submitting a Pull Request:

- Test your changes.
- Update the documentation if required.
- Update the CHANGELOG when appropriate.
- Keep pull requests focused on a single feature or fix.

---

## Issues

When reporting an issue, please include:

- Windows version
- PowerShell version
- ProfMig version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots (if applicable)

---

## Core Contributors

Current core contributors include:

- Remco de Kievit (@scorpido74)
- baseman-dev

---

## Questions

If you have questions, ideas or suggestions, please open a GitHub Discussion or create an Issue.

Thank you for helping make ProfMig better!