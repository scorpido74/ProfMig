<div align="center">

# ProfMig

### Professional Windows Profile Migration Toolkit

**Powered by**

<img src="assets/Infinigate-TechServices-logo-reversed.png" alt="Infinigate TechServices" width="220">

</div>

<div align="center">

[![Release](https://img.shields.io/github/v/release/scorpido74/ProfMig?include_prereleases&sort=semver)](https://github.com/scorpido74/ProfMig/releases)
[![Validation](https://github.com/scorpido74/ProfMig/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/scorpido74/ProfMig/actions/workflows/validate.yml)
[![Issues](https://img.shields.io/github/issues/scorpido74/ProfMig)](https://github.com/scorpido74/ProfMig/issues)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

ProfMig is a PowerShell-based Windows profile migration toolkit designed to migrate user data and supported application data between Windows user profiles in a controlled, transparent and extensible way.

The project uses a modular architecture that separates profile discovery, validation, migration, application handling, exclusions, permissions, error handling, verification, logging and reporting.

This architecture is intended to support interactive operation today while allowing future use through silent execution, automation, endpoint-management platforms and a graphical interface.

## Project status

**Current release stage: M3 – Reliability & Security completed**

Milestone 3 has been completed and formally approved after validation of ProfMig's migration safety, reliability, permissions, recovery, verification, logging and reporting behaviour.

The formal Milestone 3 validation completed **51 of 51 test scenarios successfully**, with no failed or blocked tests and no remaining Critical or High-severity defects.

A reusable Milestone 3 regression suite is also available. The current automated suite contains **47 Pester regression tests**, all of which pass successfully.

ProfMig can currently:

- Discover Windows user profiles
- Select and validate source and destination profiles
- Resolve Windows known folders for offline profiles
- Migrate standard Windows profile folders
- Prevent existing destination files from being overwritten
- Apply central migration and mandatory security exclusions
- Track copied, skipped, excluded, failed and verified files
- Record migration and verification statistics
- Generate structured migration results
- Generate human-readable migration reports
- Write structured operational logs
- Protect credential-like values and authentication tokens in logs and reports
- Run through an interactive PowerShell menu
- Detect supported applications
- Migrate Microsoft Edge portable profile data
- Migrate Google Chrome portable profile data
- Migrate Microsoft Outlook portable data and settings
- Migrate application data through generic application definitions
- Perform pre-migration profile and privilege validation
- Validate destination storage capacity
- Detect and classify file-access and copy failures
- Validate and repair destination permissions where appropriate
- Handle recoverable and critical migration errors through a structured error model
- Verify migrated files using existence and size validation
- Optionally verify migrated file content using cryptographic hashes
- Respect Windows access controls without globally weakening Windows security

Development can now proceed beyond the Milestone 3 reliability and security baseline.

## Current migration components

### Windows profile data

The Core Migration Engine currently supports migration of standard Windows user data including:

- Desktop
- Documents
- Downloads
- Pictures

Windows known folders are resolved against the selected source and destination profiles, including offline profiles.

### Microsoft Edge

ProfMig can detect Microsoft Edge profiles and migrate validated portable browser data.

Supported migration currently includes data such as:

- Bookmarks
- Bookmark backups
- Favicons

Security-sensitive and non-portable Edge data is excluded or held for review.

This includes data such as:

- Credentials
- Cookies
- Session state
- Session storage
- Authentication-related data

Additional portable Edge data remains subject to further validation.

### Google Chrome

ProfMig can detect and migrate multiple Google Chrome profiles.

Validated migration includes portable profile data while browser security exclusions prevent known sensitive or non-portable data from being transferred.

Examples of excluded data include:

- Credentials
- Authentication state
- Cookies where not considered portable
- Session data
- Account-specific state
- Other security-sensitive browser data

Existing destination Chrome data is protected from accidental overwrite.

### Microsoft Outlook

ProfMig supports detection of Classic Outlook and New Outlook installations and migrates validated portable Outlook data.

Supported portable data includes:

- PST files
- Signatures
- Outlook settings
- Print settings
- Office email templates

Non-portable or profile-dependent Outlook data is excluded or recreated.

Examples include:

- OST files
- Outlook account profiles
- Authentication state
- Send/Receive settings
- Profile-dependent cache data

Outlook authentication and account configuration must be re-established where required.

### Generic application migration

ProfMig includes a generic application migration framework.

Application definitions can describe:

- Application identity
- Detection rules
- Source and destination locations
- Include rules
- Exclude rules
- Validation rules

This allows additional applications to be supported without implementing a dedicated PowerShell migration module for every application.

## Architecture

ProfMig separates functionality into dedicated PowerShell modules.

```text
ProfMig
│
├── Configuration
├── Core Framework
├── Logging
├── Profile Inventory
├── Interactive Menu
├── Copy Engine
├── Reporting
├── Exclusion Engine
├── Application Detection
├── Generic Application Migration
├── Microsoft Edge Migration
├── Google Chrome Migration
├── Microsoft Outlook Migration
├── Migration Validation
├── Permissions and ACL Handling
├── Structured Error Handling and Recovery
└── Migration Verification and Data Integrity
```

The modules are intentionally separated so migration logic is not tied to a specific user interface.

### Copy Engine

The Copy Engine performs file migration and returns structured migration results.

It tracks:

- Files selected
- Files copied
- Files skipped
- Files excluded
- Files failed
- Files verified
- Bytes copied
- Bytes verified
- Verification failures
- Component results
- Skipped items
- Excluded items
- Structured errors
- Migration status
- Verification status

Existing destination files are not overwritten.

File-level failures are classified and handled without unnecessarily terminating the complete migration.

### Exclusion Engine

ProfMig uses a central exclusion mechanism to prevent unsafe, unnecessary or non-portable data from being migrated.

Exclusions can be based on:

- File name
- Directory name
- Relative path
- File extension
- Application-specific rules
- Mandatory security rules

Security exclusions take precedence over generic migration rules.

Known credential stores, protected Windows credential data and other security-sensitive application state are protected through mandatory exclusions.

Excluded source data is never deleted.

### Application Migration Framework

Application migration supports two provider models.

**Native providers** implement application-specific migration logic for applications requiring dedicated handling.

Current native providers include:

- Microsoft Edge
- Google Chrome
- Microsoft Outlook

**Generic providers** use application definition files to describe detection, migration and validation behavior.

This provides an extensible mechanism for adding support for additional applications.

### Validation Framework

ProfMig includes pre-migration validation capabilities designed to detect conditions that could make a migration unsafe or unreliable.

Validation includes:

- Source profile validation
- Destination profile validation
- Source and destination separation
- Profile-path validation
- Source accessibility validation
- Administrative privilege validation
- Destination storage-capacity validation
- Critical-condition detection

Critical validation failures can prevent migration from starting.

### Permissions and ACL Handling

ProfMig validates destination permissions and Windows ACL behaviour before and during migration.

Capabilities include:

- Reading destination ACL information
- Resolving source and destination user SIDs
- Verifying destination-user access
- Detecting unsafe or insufficient permissions
- Applying scoped destination permission repair where required
- Preserving Windows access-control enforcement
- Avoiding broad permissions such as Everyone Full Control

Permission repair is limited to the intended destination and does not globally weaken Windows security.

### Error Handling and Recovery

ProfMig uses a structured error model for migration, validation and recovery behaviour.

Errors can contain information such as:

- Category
- Severity
- Component
- Reason
- Recovery action
- Retry information
- Exception information
- Critical status

Supported recovery behaviour includes:

- Continue
- Retry
- Skip
- Stop

This allows predictable handling of both recoverable file-level failures and critical migration conditions.

### Migration Verification

ProfMig can verify migrated files after copy operations.

Standard verification validates:

- Destination file existence
- File size

Optional hash verification provides content-level integrity validation using supported cryptographic hash algorithms such as SHA256.

Verification results are included in structured migration results and reporting.

### Logging

ProfMig writes structured operational logs for migration and validation activity.

Logging supports severity levels including:

- Information
- Warning
- Error
- Critical
- Success

Sensitive credential-like values and Bearer tokens are redacted before diagnostic information is written to logs.

### Reporting Engine

The Reporting Engine consumes structured results produced by the migration components.

Migration reports can contain:

- ProfMig version
- Source profile
- Destination profile
- Start time
- Completion time
- Duration
- Selected migration components
- File statistics
- Bytes copied
- Files verified
- Verification failures
- Verification level
- Hash algorithm
- Skipped items
- Excluded items
- Failed items
- Structured error information
- Warnings
- Errors
- Overall migration result

Sensitive diagnostic values are protected before reports are written.

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
│   ├── Applications/
│   │   └── *.psd1
│   │
│   └── Modules/
│       ├── ProfMig.Configuration.psm1
│       ├── ProfMig.Core.psm1
│       ├── ProfMig.Logging.psm1
│       ├── ProfMig.Inventory.psm1
│       ├── ProfMig.Menu.psm1
│       ├── ProfMig.CopyEngine.psm1
│       ├── ProfMig.Reporting.psm1
│       ├── ProfMig.Exclusions.psm1
│       ├── ProfMig.Applications.psm1
│       ├── ProfMig.AppMigration.psm1
│       ├── ProfMig.Edge.psm1
│       ├── ProfMig.Chrome.psm1
│       ├── ProfMig.Outlook.psm1
│       ├── ProfMig.Validation.psm1
│       ├── ProfMig.ProfileValidation.psm1
│       ├── ProfMig.Permissions.psm1
│       ├── ProfMig.ErrorHandling.psm1
│       └── ProfMig.Verification.psm1
│
├── assets/
├── docs/
├── tests/
│   └── M3/
│       ├── Automated/
│       ├── Manual/
│       ├── Invoke-M3Tests.ps1
│       └── TestHelpers.psm1
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

ProfMig currently runs on Windows with administrative privileges.

From the project directory:

```powershell
.\Start-ProfMig.bat
```

The interactive workflow allows the operator to:

1. Select a source profile
2. Select a destination profile
3. Review detected profile information
4. Select migration components
5. Select supported applications
6. Review migration configuration
7. Validate the migration
8. Start the migration

ProfMig displays the selected migration configuration before data is copied.

## Configuration

ProfMig uses:

```text
src\Config.psd1
```

for central application configuration.

Configuration includes settings such as:

- Application information
- Runtime paths
- Log location
- Report location
- Backup location
- Application definition location
- Excluded Windows profiles
- Storage validation settings
- Verification level
- Verification hash algorithm

Runtime paths are resolved relative to the ProfMig project directory where appropriate.

## Safety principles

Migration safety is a core design principle of ProfMig.

Current controls include:

- Source and destination profiles cannot be the same
- Invalid or unsafe profile relationships can block migration
- Required administrative privileges are validated
- Destination storage capacity is validated before migration
- A configurable storage safety margin is applied
- Existing destination files are not overwritten
- Missing source folders do not stop the complete migration unnecessarily
- Locked files use bounded retry behaviour
- File-access failures are classified and recorded
- Failed copy operations are not reported as successfully migrated
- Skipped files remain visible in migration results
- Central exclusions prevent unsafe data from being copied
- Mandatory security exclusions take precedence over generic include rules
- Known credential stores and protected credential data are excluded
- ProfMig does not attempt to decrypt protected credentials
- Excluded source data is never deleted
- Browser credentials and authentication state are not intentionally migrated
- Outlook OST files are not migrated
- Application-specific non-portable data can be excluded
- Destination ACLs can be validated and repaired using scoped permissions
- Permission repair does not introduce Everyone Full Control
- Windows source access controls are respected
- Source data and source ACLs remain unchanged during migration
- Critical errors can stop unsafe migration
- Recoverable failures can use controlled retry, skip or continue behaviour
- Migrated files can be verified after copy
- Optional cryptographic hash verification can detect content differences
- Reporting does not perform migration operations
- Reporting failures do not destroy existing migration results
- Sensitive credential-like values are redacted from logs and reports
- Security failures remain visible in migration results and reports
- ProfMig does not rely on globally weakening Windows security controls

These controls form the Milestone 3 reliability and security baseline for future ProfMig development.

## Testing

ProfMig includes reusable regression testing for the Milestone 3 reliability and security baseline.

The automated M3 regression suite contains **47 Pester tests** covering:

- Profile validation
- Privilege validation
- Storage validation
- File handling
- Permissions and ACLs
- Recovery and error handling
- Migration verification
- Security behaviour
- Logging
- Reporting

Run the complete automated M3 regression suite from the repository root:

```powershell
& '.\tests\M3\Invoke-M3Tests.ps1'
```

The current regression baseline is:

```text
Total        : 47
Passed       : 47
Failed       : 0
Skipped      : 0
Pending      : 0
Inconclusive : 0

M3 AUTOMATED REGRESSION: PASS
```

Two scenarios retain a manual or hybrid component because they depend on the actual Windows execution or machine context:

- Non-elevated ProfMig execution
- Verification that ProfMig does not globally weaken Windows security controls

These procedures are documented in `tests\M3\Manual\M3-Manual-Tests.md`.

The automated regression suite complements the formal Milestone 3 validation. It does not replace the **51 formal M3 validation scenarios**, all of which passed during Milestone 3 acceptance testing.

## Requirements

Current requirements:

- Windows 10 or Windows 11
- Windows Server 2019 or later where applicable
- Windows PowerShell 5.1
- Local administrative privileges

ProfMig is primarily developed and validated using Windows PowerShell 5.1.

The current M3 regression suite is compatible with Pester 3.4.

## Roadmap

### M1 – Core Migration Engine

**Status: Completed**

Core functionality:

- [x] Core framework
- [x] Configuration
- [x] Logging
- [x] Interactive menu
- [x] Windows profile inventory
- [x] Core profile Copy Engine
- [x] Migration Reporting Engine

### M2 – Application Migration

**Status: Completed**

Application migration functionality:

- [x] Application detection framework
- [x] Microsoft Edge migration
- [x] Google Chrome migration
- [x] Microsoft Outlook migration
- [x] Generic application migration framework
- [x] Central application exclusions
- [x] Application migration integration
- [x] End-to-end application migration validation

M2 was validated using separate Windows source and destination profiles.

### M3 – Reliability & Security

**Status: Completed and approved**

M3 established the migration reliability and security baseline.

Completed functionality includes:

- [x] Profile validation
- [x] Privilege validation
- [x] Storage and capacity validation
- [x] File-access and locked-file handling
- [x] Destination permissions and ACL handling
- [x] Structured error handling
- [x] Recovery behaviour
- [x] Migration verification
- [x] Optional hash-based integrity verification
- [x] Security validation
- [x] Sensitive-data protection in logging and reporting
- [x] Migration reporting validation
- [x] Formal M3 security and reliability validation
- [x] Reusable automated M3 regression suite
- [x] Manual/hybrid regression procedures

Formal M3 validation result:

```text
Tests executed : 51
Tests passed   : 51
Tests failed   : 0
Tests blocked  : 0

Open Critical defects : 0
Open High defects     : 0

M3 status: APPROVED
```

The post-validation automated regression baseline is **47/47 PASS**.

Detailed validation evidence is documented in `docs/M3-Security-Reliability-Test-Plan.md`.

## Future direction

The modular architecture and M3 reliability baseline are intended to support future functionality such as:

- Additional Windows profile components
- Additional application definitions
- Additional browser migration capabilities
- Outlook migration enhancements
- OneDrive migration
- Backup and rollback capabilities
- GUI operation
- Silent execution
- Machine-readable reports
- Automation
- Intune integration
- Endpoint-management integration
- Centralized reporting
- Additional automated testing and release validation

These items represent project direction and should not be considered implemented until their corresponding development work has been completed.

## Contributing

Contributions are welcome.

See `CONTRIBUTING.md` for contribution guidelines.

## Security

Security issues should be reported according to the process described in `SECURITY.md`.

ProfMig intentionally avoids migrating known credentials, authentication tokens and other security-sensitive application state where this data cannot be migrated safely.

## License

ProfMig is licensed under the MIT License.

See `LICENSE` for details.

## Maintainers

ProfMig is maintained by:

- Remco de Kievit ([@scorpido74](https://github.com/scorpido74))
- Bas van Ek ([@baseman-dev](https://github.com/baseman-dev))