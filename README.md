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

The project uses a modular architecture that separates profile discovery, validation, migration, application handling, exclusions, permissions, error handling, verification, logging, reporting and deployment.

ProfMig supports interactive migration workflows as well as packaged runtime deployment, command-line operation, silent execution and Microsoft Intune Win32 deployment.

---

## Project status

**Current development stage: M5 – Deployment & Operations**

Milestone 3 established and formally validated the ProfMig reliability and security baseline.

The formal Milestone 3 validation completed:

```text
Tests executed : 51
Tests passed   : 51
Tests failed   : 0
Tests blocked  : 0

Open Critical defects : 0
Open High defects     : 0

M3 status: APPROVED
```

A reusable Milestone 3 regression suite is also available. The automated baseline contains:

```text
Total        : 47
Passed       : 47
Failed       : 0
Skipped      : 0
Pending      : 0
Inconclusive : 0

M3 AUTOMATED REGRESSION: PASS
```

Development has since progressed into packaging, automation and endpoint deployment capabilities.

Current functionality includes:

- Windows profile discovery
- Source and destination profile selection
- Profile validation
- Windows known-folder resolution
- Standard Windows profile data migration
- Microsoft Edge migration
- Google Chrome migration
- Microsoft Outlook migration
- Generic application migration
- Central migration exclusions
- Mandatory security exclusions
- Storage-capacity validation
- File-access and locked-file handling
- Destination permissions and ACL validation
- Structured error handling and recovery
- Migration verification
- Optional SHA256 verification
- Structured logging
- Migration reporting
- Sensitive-data protection in logs and reports
- Interactive migration operation
- Command-line and silent operation
- Runtime packaging
- Version and build metadata
- Controlled deployment and upgrade
- Runtime uninstall
- Microsoft Intune Win32 packaging
- Version-specific Intune detection
- SYSTEM-context runtime deployment

---

## Current migration components

### Windows profile data

ProfMig supports migration of standard Windows user data including:

- Desktop
- Documents
- Downloads
- Pictures
- Music
- Videos
- Favorites
- Links

Windows known folders are resolved against the selected source and destination profiles, including offline profiles.

Existing destination files are protected from accidental overwrite.

---

### Microsoft Edge

ProfMig can detect Microsoft Edge profiles and migrate validated portable browser data.

Supported migration includes portable data such as:

- Bookmarks
- Bookmark backups
- Favicons

Security-sensitive and non-portable data is excluded or held for review.

Examples include:

- Credentials
- Cookies
- Session state
- Session storage
- Authentication-related data

ProfMig does not attempt to transfer browser authentication state that cannot be migrated safely.

---

### Google Chrome

ProfMig can detect and migrate multiple Google Chrome profiles.

Validated migration includes portable profile data while browser security exclusions prevent known sensitive or non-portable information from being transferred.

Examples of excluded data include:

- Credentials
- Authentication state
- Cookies where not considered portable
- Session data
- Account-specific state
- Other security-sensitive browser data

Existing destination Chrome data is protected from accidental overwrite.

---

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

---

### Generic application migration

ProfMig includes a generic application migration framework.

Application definitions can describe:

- Application identity
- Detection rules
- Source locations
- Destination locations
- Include rules
- Exclude rules
- Validation rules

This allows additional applications to be supported without implementing a dedicated PowerShell migration module for every application.

---

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
├── Migration Orchestration
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

The modules are intentionally separated so migration logic is not tied to a specific user interface or deployment mechanism.

This allows the same migration framework to support:

- Interactive operation
- Command-line operation
- Silent execution
- Packaged deployment
- Endpoint-management deployment
- Future graphical interfaces

---

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
- Structured errors
- Migration status
- Verification status

Existing destination files are not overwritten.

File-level failures are classified and handled without unnecessarily terminating the complete migration.

---

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

---

### Application Migration Framework

Application migration supports two provider models.

**Native providers** implement application-specific migration logic for applications requiring dedicated handling.

Current native providers include:

- Microsoft Edge
- Google Chrome
- Microsoft Outlook

**Generic providers** use application definition files to describe detection, migration and validation behavior.

This provides an extensible mechanism for adding support for additional applications.

---

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

Deployment through an endpoint-management platform does not bypass these migration validations.

---

### Permissions and ACL Handling

ProfMig validates destination permissions and Windows ACL behavior before and during migration.

Capabilities include:

- Reading destination ACL information
- Resolving source and destination user SIDs
- Verifying destination-user access
- Detecting unsafe or insufficient permissions
- Applying scoped destination permission repair where required
- Preserving Windows access-control enforcement
- Avoiding broad permissions such as Everyone Full Control

Permission repair is limited to the intended destination and does not globally weaken Windows security.

---

### Error Handling and Recovery

ProfMig uses a structured error model for migration, validation and recovery behavior.

Errors can contain information such as:

- Category
- Severity
- Component
- Reason
- Recovery action
- Retry information
- Exception information
- Critical status

Supported recovery behavior includes:

- Continue
- Retry
- Skip
- Stop

This allows predictable handling of recoverable file-level failures and critical migration conditions.

---

### Migration Verification

ProfMig can verify migrated files after copy operations.

Standard verification validates:

- Destination file existence
- File size

Optional hash verification provides content-level integrity validation using supported cryptographic hash algorithms such as SHA256.

Verification results are included in structured migration results and reporting.

---

### Logging

ProfMig writes structured operational logs for migration and validation activity.

Logging supports severity levels including:

- Information
- Warning
- Error
- Critical
- Success

Sensitive credential-like values and authentication tokens are redacted before diagnostic information is written to logs.

---

### Reporting Engine

The Reporting Engine consumes structured results produced by migration components.

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

The underlying migration data remains structured for future GUI, automation and machine-readable reporting functionality.

---

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
│   ├── Profiles/
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
│       ├── ProfMig.Verification.psm1
│       └── ProfMig.Migration.psm1
│
├── build/
│   ├── New-ProfMigPackage.ps1
│   ├── Deploy-ProfMig.ps1
│   ├── Uninstall-ProfMig.ps1
│   │
│   └── Intune/
│       ├── New-ProfMigIntunePackage.ps1
│       └── Detect-ProfMig.ps1
│
├── assets/
├── docs/
├── tests/
├── Start-ProfMig.bat
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── SECURITY.md
```

Generated packages, logs and reports are not stored in the Git repository.

External build tools are also excluded from the repository.

---

## Running ProfMig

ProfMig can be operated interactively or through supported command-line and silent workflows.

### Interactive operation

From the project or deployed ProfMig directory:

```powershell
.\Start-ProfMig.bat
```

The interactive workflow allows the operator to:

1. Select a source profile.
2. Select a destination profile.
3. Review detected profile information.
4. Select migration components.
5. Select supported applications.
6. Review migration configuration.
7. Validate the migration.
8. Start the migration.

ProfMig displays the selected migration configuration before data is copied.

---

## Command-line and silent operation

ProfMig includes migration orchestration designed to support non-interactive operation.

The command-line framework can resolve migration profiles using supported profile identifiers such as:

- SID
- Profile path

Migration configuration is validated before migration operations are started.

Default profile-folder selections can include:

- Desktop
- Documents
- Downloads
- Pictures
- Music
- Videos
- Favorites
- Links

Silent operation does not disable ProfMig's safety controls.

Profile validation, storage validation, exclusions, permissions, error handling and verification remain applicable.

For detailed command-line guidance, see:

[`docs/Command-Line-and-Silent-Mode.md`](docs/Command-Line-and-Silent-Mode.md)

---

## Packaging

ProfMig can be converted from the development repository into a deployable runtime package.

The package builder is:

```text
build\New-ProfMigPackage.ps1
```

A normal runtime package contains only the files required to run ProfMig.

Development-only content such as tests is not included in the deployed runtime.

Runtime packages contain build metadata in:

```text
ProfMig.Build.psd1
```

Metadata includes information such as:

- Application name
- Version
- Build
- Git commit
- Git working-tree state
- Build timestamp

For detailed packaging information, see:

[`docs/Packaging-and-Application-Structure.md`](docs/Packaging-and-Application-Structure.md)

---

## Deployment and updates

ProfMig includes deployment and uninstall scripts:

```text
build\Deploy-ProfMig.ps1
build\Uninstall-ProfMig.ps1
```

The default deployment location is:

```text
C:\Program Files\ProfMig
```

Deployment supports:

- Clean installation
- Existing-installation detection
- Version-aware deployment
- Upgrade handling
- Downgrade protection
- Deployment staging
- Validation before activation
- Persistent-data preservation
- Uninstall

The deployment process is separate from the actual profile migration.

Installing or updating ProfMig does not automatically start a migration.

Persistent data currently includes:

```text
Logs
Reports
Backup
```

The standard uninstall process preserves these directories.

For detailed deployment behavior, see:

[`docs/Deployment-and-Update-Strategy.md`](docs/Deployment-and-Update-Strategy.md)

---

## Microsoft Intune deployment

ProfMig can be packaged as a Microsoft Intune Win32 application.

The Intune build process generates two version-linked artifacts.

### Win32 package

```text
dist\Intune\Package\ProfMig-<version>.intunewin
```

Example:

```text
ProfMig-0.2.0.intunewin
```

### Detection script

```text
dist\Intune\Detection\Detect-ProfMig-<version>.ps1
```

Example:

```text
Detect-ProfMig-0.2.0.ps1
```

The version-specific detection script verifies the installed runtime using:

```text
C:\Program Files\ProfMig\ProfMig.Build.psd1
```

The Intune deployment lifecycle has been validated using the Windows SYSTEM security context for:

- Runtime installation
- Exact version detection
- Incorrect-version rejection
- Runtime uninstall
- Persistent-data preservation
- Detection after uninstall

Runtime deployment through Intune and actual profile migration are intentionally separate operations.

SYSTEM has been validated as a deployment context. This does not imply that SYSTEM is automatically the correct execution context for an actual user profile migration.

Profile migration continues to require its own source, destination, privilege, storage, permissions and security validation.

For complete Intune packaging and configuration guidance, see:

[`docs/Microsoft-Intune-Deployment.md`](docs/Microsoft-Intune-Deployment.md)

---

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

Runtime paths are resolved relative to the ProfMig runtime where appropriate.

---

## Versioning

ProfMig uses application version information from:

```text
src\Config.psd1
```

Runtime builds generate:

```text
ProfMig.Build.psd1
```

The generated metadata is used for:

- Runtime identification
- Deployment validation
- Installed-version detection
- Upgrade decisions
- Downgrade protection
- Intune detection

The same application version is used when generating the Intune Win32 package and corresponding detection artifact.

For additional information, see:

[`docs/Versioning-and-Build-Information.md`](docs/Versioning-and-Build-Information.md)

---

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
- Locked files use bounded retry behavior
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
- Recoverable failures can use controlled retry, skip or continue behavior
- Migrated files can be verified after copy
- Optional cryptographic hash verification can detect content differences
- Reporting does not perform migration operations
- Reporting failures do not destroy existing migration results
- Sensitive credential-like values are redacted from logs and reports
- Security failures remain visible in migration results and reports
- Deployment does not automatically initiate migration
- Endpoint deployment does not bypass migration validation
- SYSTEM ownership of a destination user profile is never assumed
- ProfMig does not rely on globally weakening Windows security controls

These controls form the reliability and security baseline for future ProfMig development.

---

## Testing

ProfMig contains automated and manual tests covering migration, reliability, security, packaging, deployment and automation functionality.

### Milestone 3 regression suite

The automated M3 regression suite contains **47 Pester tests** covering:

- Profile validation
- Privilege validation
- Storage validation
- File handling
- Permissions and ACLs
- Recovery and error handling
- Migration verification
- Security behavior
- Logging
- Reporting

Run the complete M3 regression suite from the repository root:

```powershell
& '.\tests\M3\Invoke-M3Tests.ps1'
```

Current M3 automated baseline:

```text
Total        : 47
Passed       : 47
Failed       : 0
Skipped      : 0
Pending      : 0
Inconclusive : 0

M3 AUTOMATED REGRESSION: PASS
```

Two M3 scenarios retain a manual or hybrid component because they depend on the actual Windows execution or machine context:

- Non-elevated ProfMig execution
- Verification that ProfMig does not globally weaken Windows security controls

These procedures are documented in:

```text
tests\M3\Manual\M3-Manual-Tests.md
```

The automated regression suite complements the formal Milestone 3 validation and does not replace the **51 formal M3 validation scenarios**, all of which passed during Milestone 3 acceptance testing.

Detailed M3 validation evidence is documented in:

[`docs/M3-Security-Reliability-Test-Plan.md`](docs/M3-Security-Reliability-Test-Plan.md)

### Deployment tests

Additional tests validate capabilities including:

- Runtime packaging
- Version metadata
- Deployment
- Uninstall
- Version handling
- Command-line operation
- Intune detection

Relevant tests include:

```text
tests\Test-ProfMigDeployment.ps1
tests\Test-ProfMigUninstall.ps1
tests\Test-ProfMigVersioning.ps1
tests\Test-ProfMigCommandLine.ps1
tests\Test-ProfMigIntuneDetection.ps1
```

---

## Requirements

Current runtime requirements:

- Windows 10 or Windows 11
- Windows Server 2019 or later where applicable
- Windows PowerShell 5.1
- Local administrative privileges where required by the operation

ProfMig is primarily developed and validated using Windows PowerShell 5.1.

The current M3 regression suite is compatible with Pester 3.4.

Microsoft Intune deployment additionally requires a supported Intune Win32 application environment and the Intune Management Extension on the managed endpoint.

The Microsoft Win32 Content Prep Tool is required only on the build workstation when generating `.intunewin` packages. It is not part of the ProfMig endpoint runtime.

---

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

---

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

---

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
- [x] Recovery behavior
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

---

### M5 – Deployment & Operations

**Status: In development**

Current M5 capabilities include:

- [x] Runtime packaging
- [x] Application structure for deployment
- [x] Command-line operation
- [x] Silent and non-interactive operation
- [x] Migration profile configuration
- [x] Version and build metadata
- [x] Controlled deployment
- [x] Runtime uninstall
- [x] Persistent-data preservation
- [x] Version-aware deployment
- [x] Downgrade protection
- [x] Microsoft Intune source packaging
- [x] Microsoft Intune Win32 package generation
- [x] Version-specific Intune detection
- [x] SYSTEM-context runtime installation
- [x] SYSTEM-context runtime detection
- [x] SYSTEM-context runtime uninstall
- [ ] Final Intune upgrade validation
- [ ] Migration execution-context validation
- [ ] Final M5 deployment acceptance

---

## Future direction

The modular architecture and reliability baseline are intended to support further functionality such as:

- Additional Windows profile components
- Additional application definitions
- Additional browser migration capabilities
- Outlook migration enhancements
- OneDrive migration
- Extended backup and rollback capabilities
- Graphical user interface
- Machine-readable reports
- Additional endpoint-management integration
- Centralized reporting
- Expanded automated deployment testing
- Additional release validation

These items represent project direction and should not be considered implemented until their corresponding development work has been completed.

---

## Deployment model

A key ProfMig design principle is the separation between application deployment and migration execution.

```text
Endpoint management
       |
       v
Install / update ProfMig runtime
       |
       v
Detect installed version
       |
       v
ProfMig available on endpoint
       |
       +--------------------------+
                                  |
                                  v
                     Controlled migration request
                                  |
                                  v
                       Migration validation
                                  |
                                  v
                         Profile migration
                                  |
                                  v
                      Verification & reporting
```

Installing ProfMig does not itself authorize or initiate a profile migration.

This makes it possible to stage ProfMig on managed endpoints before a migration is scheduled.

---

## Documentation

Additional technical documentation is available in the `docs` directory.

Key documents include:

- [Packaging and Application Structure](docs/Packaging-and-Application-Structure.md)
- [Command-Line and Silent Mode](docs/Command-Line-and-Silent-Mode.md)
- [Deployment and Update Strategy](docs/Deployment-and-Update-Strategy.md)
- [Microsoft Intune Deployment](docs/Microsoft-Intune-Deployment.md)
- [Versioning and Build Information](docs/Versioning-and-Build-Information.md)
- [Error Handling and Recovery](docs/Error-Handling-and-Recovery.md)
- [M3 Security and Reliability Test Plan](docs/M3-Security-Reliability-Test-Plan.md)

---

## Contributing

Contributions are welcome.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for contribution guidelines.

---

## Security

Security issues should be reported according to the process described in [`SECURITY.md`](SECURITY.md).

ProfMig intentionally avoids migrating known credentials, authentication tokens and other security-sensitive application state where this data cannot be migrated safely.

Security and migration validation must remain active regardless of whether ProfMig is started interactively, silently or through an endpoint-management workflow.

---

## License

ProfMig is licensed under the MIT License.

See [`LICENSE`](LICENSE) for details.

---

## Maintainers

ProfMig is maintained by:

- Remco de Kievit ([@scorpido74](https://github.com/scorpido74))
- Bas van Ek ([@baseman-dev](https://github.com/baseman-dev))