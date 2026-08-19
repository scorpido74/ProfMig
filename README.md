<div align="center">

# ProfMig

### Professional Windows Profile Migration Toolkit

<img src="assets/infinigate-logo.png" alt="Infinigate" width="180">

**Powered by Infinigate**

</div>

<div align="center">

[![Release](https://img.shields.io/github/v/release/scorpido74/ProfMig?include_prereleases&sort=semver)](https://github.com/scorpido74/ProfMig/releases)
[![Build](https://github.com/scorpido74/ProfMig/actions/workflows/validate.yml/badge.svg)](https://github.com/scorpido74/ProfMig/actions)
[![Issues](https://img.shields.io/github/issues/scorpido74/ProfMig)](https://github.com/scorpido74/ProfMig/issues)
[![License](https://img.shields.io/github/license/scorpido74/ProfMig)](LICENSE)

</div>


Professional Windows Profile Migration Toolkit

ProfMig is a PowerShell-based Windows profile migration toolkit designed to migrate user data between Windows user profiles in a controlled, transparent and extensible way.

The project is being developed with a modular architecture so that the migration engine can later be used through an interactive menu, GUI, silent execution, automation and endpoint management platforms.

## Project status

**Current release stage:** M1 – Core Migration Engine completed

The core migration framework is operational.

ProfMig can currently:

- Discover Windows user profiles
- Select a source and destination profile
- Migrate standard Windows profile folders
- Prevent existing destination files from being overwritten
- Apply file exclusions
- Track copied, skipped, excluded and failed files
- Record migration statistics
- Generate structured migration results
- Generate human-readable migration reports
- Write operational logs
- Run through an interactive PowerShell menu

Development now continues with **M2**.

## Current migration components

The Core Migration Engine currently supports:

- Desktop
- Documents
- Downloads
- Pictures

Support for additional Windows and application data will be added in later milestones.

## Architecture

ProfMig uses separate PowerShell modules for the major application components.

```text
ProfMig
│
├── Configuration
│
├── Core Framework
│
├── Logging
│
├── Profile Inventory
│
├── Interactive Menu
│
├── Copy Engine
│
└── Reporting
```

The modules are intentionally separated so that migration logic is not tied to a specific user interface.

### Copy Engine

The Copy Engine performs profile data migration and returns structured migration results.

It tracks:

- Files selected
- Files copied
- Files skipped
- Files excluded
- Files failed
- Bytes copied
- Component results
- Skipped items
- Excluded items
- Errors
- Migration status

Existing destination files are not overwritten.

### Reporting Engine

The Reporting Engine consumes results produced by the Copy Engine.

It provides the following overall migration states:

- Success
- Success with warnings
- Failed

Migration reports contain:

- ProfMig version
- Source profile
- Destination profile
- Start time
- Completion time
- Duration
- Selected migration components
- File statistics
- Bytes copied
- Skipped items
- Excluded items
- Failed items
- Warnings
- Errors
- Overall migration result

Reports are stored in the configured `Reports` directory.

The underlying migration data remains structured for future GUI, automation and machine-readable reporting functionality.

## Project structure

```text
ProfMig/
│
├── src/
│   ├── ProfMig.ps1
│   ├── Config.psd1
│   │
│   └── Modules/
│       ├── ProfMig.Configuration.psm1
│       ├── ProfMig.Core.psm1
│       ├── ProfMig.Logging.psm1
│       ├── ProfMig.Inventory.psm1
│       ├── ProfMig.Menu.psm1
│       ├── ProfMig.CopyEngine.psm1
│       └── ProfMig.Reporting.psm1
│
├── Logs/
├── Reports/
├── Start-ProfMig.bat
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── SECURITY.md
```

Generated log and report files are not stored in the Git repository.

## Running ProfMig

ProfMig should currently be run on Windows with administrative privileges.

From the project directory:

```powershell
.\Start-ProfMig.bat
```

The interactive menu allows you to:

1. Select a source profile
2. Select a destination profile
3. Review the migration configuration
4. Start the migration
5. Exit ProfMig

Before copying data, ProfMig displays the selected profiles and asks for confirmation.

## Configuration

ProfMig uses:

```text
src\Config.psd1
```

for application configuration.

Current configuration includes:

- Application name
- Version
- Build
- Log location
- Report location
- Backup location
- Excluded Windows profiles

Runtime paths are resolved relative to the ProfMig project directory.

## Safety principles

The Core Migration Engine follows several basic safety rules:

- Source and destination profiles cannot be the same
- Existing destination files are not overwritten
- Missing source folders do not stop the complete migration
- Failed copy operations are recorded
- Skipped files remain visible in migration results
- Reporting does not perform migration operations
- Reporting failures do not destroy existing migration results
- Credentials and authentication tokens must not be written to reports

Additional migration safety controls will be added in later milestones.

## Requirements

Current development requirements:

- Windows 10/11
- Windows Server 2019 or later
- Windows PowerShell 5.1
- Local administrative privileges

## Roadmap

### M1 – Core Migration Engine

**Status: Completed**

Core functionality includes:

- [x] Core framework
- [x] Configuration
- [x] Logging
- [x] Interactive menu
- [x] Windows profile inventory
- [x] Core profile Copy Engine
- [x] Migration Reporting Engine

### M2 – Profile Migration Components

**Status: Next**

M2 expands ProfMig beyond the core Windows profile folders with additional profile and application migration functionality.

Further functionality is tracked through GitHub Issues and Milestones.

## Future direction

The modular ProfMig architecture is intended to support functionality such as:

- Additional Windows profile components
- Browser migration
- Outlook migration
- OneDrive migration
- Application-specific migration
- Backup and rollback capabilities
- GUI operation
- Silent execution
- Machine-readable reports
- Automation
- Intune and endpoint-management integration
- Centralized reporting

These items are part of the project direction and should not be considered implemented until their corresponding milestones are completed.

## Contributing

Contributions are welcome.

See `CONTRIBUTING.md` for contribution guidelines.

## Security

Security issues should be reported according to the process described in `SECURITY.md`.

## License

This project is licensed under the MIT License.

See `LICENSE` for details.

## Maintainers

ProfMig is maintained by:

- Remco de Kievit ([@scorpido74](https://github.com/scorpido74))
- Bas van Ek ([@baseman-dev](https://github.com/baseman-dev))
