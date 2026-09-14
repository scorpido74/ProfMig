<div align="center">

# ProfMig

### Professional Windows Profile Migration Toolkit

**Powered by**

<img src="assets/Infinigate-TechServices-logo-reversed.png" alt="Infinigate TechServices" width="220">

</div>

<div align="center">

[![Release](https://img.shields.io/github/v/release/scorpido74/ProfMig?include_prereleases\&sort=semver)](https://github.com/scorpido74/ProfMig/releases)
[![Validation](https://github.com/scorpido74/ProfMig/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/scorpido74/ProfMig/actions/workflows/validate.yml)
[![Issues](https://img.shields.io/github/issues/scorpido74/ProfMig)](https://github.com/scorpido74/ProfMig/issues)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

ProfMig is a PowerShell-based Windows profile migration toolkit designed to migrate user data and supported application data between Windows user profiles in a controlled, transparent and extensible way.

The project uses a modular architecture that separates profile discovery, configuration, validation, migration, application handling, exclusions, permissions, error handling, verification, logging, reporting and deployment.

ProfMig supports interactive migration, command-line and silent operation, standalone runtime packaging, remote/RMM execution and Microsoft Intune Win32 deployment.

---

## Project status

**Current version: 0.5.0 Development**

**Current development stage: M5 – Deployment & Operations**

Milestone 3 established and formally validated the ProfMig reliability and security baseline.

Formal Milestone 3 validation:

```text
Tests executed : 51
Tests passed   : 51
Tests failed   : 0
Tests blocked  : 0

Open Critical defects : 0
Open High defects     : 0

M3 status: APPROVED
```

The reusable Milestone 3 automated regression suite currently reports:

```text
Total        : 47
Passed       : 47
Failed       : 0
Skipped      : 0
Pending      : 0
Inconclusive : 0

M3 AUTOMATED REGRESSION: PASS
```

Milestone 5 extends ProfMig with packaging, unattended execution, deployment automation, remote-management support, code signing and release-integrity validation.

Current Milestone 5 automated validation:

```text
M5 suites     : 13
Passed        : 13
Failed        : 0

M5 AUTOMATED REGRESSION: PASS
```

Actual Microsoft Intune Win32 deployment to a managed test device remains **PENDING** as an environment-dependent integration validation.

Final Milestone 5 acceptance remains open while this validation is pending.

---

## Current capabilities

ProfMig currently includes:

### Profile migration

* Windows user-profile discovery
* Source and destination profile selection
* SID and profile-path based profile resolution
* Windows known-folder resolution
* Offline profile handling
* Configurable migration components
* Existing destination-file protection

Supported standard profile components include:

* Desktop
* Documents
* Downloads
* Pictures
* Music
* Videos
* Favorites
* Links

### Application migration

* Microsoft Edge
* Google Chrome
* Microsoft Outlook
* Generic application definitions
* Central application exclusions
* Mandatory security exclusions

### Reliability and security

* Pre-migration validation
* Administrative privilege validation
* Storage-capacity validation
* File-access and locked-file handling
* Destination ACL validation
* Scoped permission repair
* Structured error handling
* Controlled retry and recovery
* Post-copy verification
* Optional SHA256 verification
* Sensitive-data protection in logs and reports

### Automation and deployment

* Interactive operation
* Command-line operation
* Silent migration
* External configuration files
* Configurable migration profiles
* Runtime packaging
* Version and build metadata
* Controlled installation and upgrade
* Runtime uninstall
* Persistent-data preservation
* Microsoft Intune Win32 packaging
* Version-specific Intune detection
* SYSTEM-context execution
* Vendor-neutral RMM/remote execution
* Predictable exit-code propagation
* Remote result interpretation
* Authenticode code signing
* SHA256 release-package integrity validation
* Automated deployment regression testing

---

## Architecture

ProfMig separates migration functionality into dedicated PowerShell modules.

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

The migration engine is intentionally independent from the user interface and deployment mechanism.

The same runtime can therefore support:

* Interactive operation
* Command-line operation
* Silent execution
* Standalone deployment
* Endpoint-management deployment
* RMM execution
* Future graphical interfaces

---

## Windows profile migration

ProfMig can migrate standard Windows user data between separate Windows profiles.

Supported components include:

```text
Desktop
Documents
Downloads
Pictures
Music
Videos
Favorites
Links
```

Windows known folders are resolved against the selected source and destination profiles, including offline profiles.

Source and destination profiles are validated before migration starts.

Existing destination files are protected from accidental overwrite.

---

## Microsoft Edge

ProfMig can detect Microsoft Edge profiles and migrate validated portable browser data.

Supported portable data includes items such as:

* Bookmarks
* Bookmark backups
* Favicons

Security-sensitive and non-portable browser state is excluded.

Examples include:

* Credentials
* Authentication state
* Cookies where not considered portable
* Session state
* Session storage
* Other protected browser data

ProfMig does not attempt to transfer browser authentication state that cannot be migrated safely.

---

## Google Chrome

ProfMig can detect Google Chrome installations and multiple Chrome profiles.

Portable browser profile data can be migrated while security-sensitive and non-portable data is excluded.

Examples of excluded data include:

* Credentials
* Authentication state
* Session data
* Account-specific state
* Other security-sensitive browser information

Existing destination Chrome data is protected from accidental overwrite.

---

## Microsoft Outlook

ProfMig supports detection of both Classic Outlook and New Outlook.

Supported portable Outlook data includes:

* PST files
* Signatures
* Outlook settings
* Print settings
* Office email templates

Non-portable or profile-dependent data is excluded or recreated.

Examples include:

* OST files
* Outlook account profiles
* Authentication state
* Send/Receive settings
* Profile-dependent cache data

Outlook authentication and account configuration must be re-established where required.

---

## Generic application migration

ProfMig includes a generic application migration framework.

Application definitions can describe:

* Application identity
* Detection rules
* Source locations
* Destination locations
* Include rules
* Exclude rules
* Validation rules

This allows additional applications to be supported without requiring a dedicated PowerShell migration module for every application.

Two application-provider models are supported:

### Native providers

Native providers implement application-specific migration logic.

Current native providers include:

* Microsoft Edge
* Google Chrome
* Microsoft Outlook

### Generic providers

Generic providers use application definition files to describe detection, migration and validation behaviour.

---

## Migration profiles

Migration behaviour can be defined through reusable migration profiles.

Current built-in profiles include:

### Standard

Designed for normal profile migration.

Includes the standard Windows profile components and supported application migration.

### Minimal

Designed for restricted or validation migrations.

Includes:

```text
Desktop
Documents
```

Application migration is disabled.

Migration-profile selection follows this precedence:

```text
Explicit -MigrationProfile
        |
        v
Config.Migration.DefaultProfile
        |
        v
Built-in fallback
```

This allows central configuration to define the normal migration behaviour while still permitting explicit command-line overrides.

---

## Validation framework

ProfMig validates migration conditions before copying data.

Validation includes:

* Source profile validation
* Destination profile validation
* Source and destination separation
* Profile-path validation
* Source accessibility
* Administrative privileges
* Destination storage capacity
* Configuration validity
* Migration-profile validity
* Critical-condition detection

Critical validation failures can prevent migration from starting.

Deployment through an endpoint-management or RMM platform does not bypass migration validation.

---

## Permissions and ACL handling

ProfMig validates Windows permissions and destination ACL behaviour before and during migration.

Capabilities include:

* Reading destination ACL information
* Resolving source and destination SIDs
* Verifying destination-user access
* Detecting insufficient permissions
* Applying scoped destination permission repair
* Preserving Windows access-control enforcement
* Avoiding broad permissions such as `Everyone: Full Control`

Permission repair is limited to the intended destination.

ProfMig does not globally weaken Windows security controls.

---

## Error handling and recovery

ProfMig uses a structured error model.

Errors can include:

* Category
* Severity
* Component
* Reason
* Recovery action
* Retry information
* Exception information
* Critical status

Supported recovery behaviour includes:

```text
Continue
Retry
Skip
Stop
```

This allows recoverable file-level failures to be handled without unnecessarily terminating the complete migration.

Critical migration conditions can still stop execution.

---

## Migration verification

ProfMig can verify migrated files after copy operations.

Standard verification validates:

* Destination file existence
* File size

Optional cryptographic verification can additionally validate file contents using SHA256.

Verification results are included in structured migration results and reports.

---

## Logging and reporting

ProfMig writes structured operational logs covering migration and validation activity.

Logging supports severity levels including:

* Information
* Warning
* Error
* Critical
* Success

Sensitive credential-like values and authentication tokens are redacted before diagnostic information is written.

Migration reports can contain:

* ProfMig version and build
* Source profile
* Destination profile
* Start and completion time
* Duration
* Selected migration components
* File statistics
* Bytes copied
* Files verified
* Verification failures
* Verification level
* Hash algorithm
* Skipped items
* Excluded items
* Failed items
* Structured errors
* Warnings
* Overall migration result

Reporting does not perform migration operations and reporting failures do not destroy existing migration results.

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
│   │   ├── Standard.psd1
│   │   └── Minimal.psd1
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
├── docs/
├── tests/
│   ├── M3/
│   └── M5/
│
├── examples/
│   └── remote-deployment/
│
├── assets/
├── Start-ProfMig.bat
├── CHANGELOG.md
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

ProfMig can be operated interactively or through command-line and silent workflows.

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

No data is copied before the migration configuration has been validated.

---

## Command-line and silent operation

ProfMig supports unattended operation through command-line parameters.

Profile identifiers can include:

* SID
* Profile path

Migration configuration can be supplied through:

* Command-line parameters
* External configuration files
* Migration profiles

Silent execution does not disable ProfMig safety controls.

Validation, storage checks, exclusions, permissions, error handling and verification remain active.

For detailed command-line guidance, see:

[`docs/Command-Line-and-Silent-Mode.md`](docs/Command-Line-and-Silent-Mode.md)

---

## Exit codes

ProfMig uses predictable process exit codes so management platforms and automation wrappers can interpret the result.

Successful migrations, successful migrations with warnings and validation/configuration failures remain distinguishable at process level.

Exit codes are preserved through supported launcher and remote-execution workflows.

This allows endpoint-management and RMM platforms to determine whether ProfMig:

* completed successfully;
* completed with warnings;
* rejected configuration;
* rejected profile selection;
* encountered another controlled failure.

---

## Packaging

ProfMig can be converted from the development repository into a standalone runtime package.

Package builder:

```text
build\New-ProfMigPackage.ps1
```

Development-only content such as tests is excluded from the deployed runtime.

Runtime packages contain generated build metadata:

```text
ProfMig.Build.psd1
```

Metadata includes:

* Application name
* Version
* Build
* Git commit
* Git working-tree state
* Build timestamp

For detailed packaging information, see:

[`docs/Packaging-and-Application-Structure.md`](docs/Packaging-and-Application-Structure.md)

---

## Deployment and updates

ProfMig includes deployment and uninstall tooling:

```text
build\Deploy-ProfMig.ps1
build\Uninstall-ProfMig.ps1
```

Default deployment location:

```text
C:\Program Files\ProfMig
```

Deployment supports:

* Clean installation
* Existing-installation detection
* Version-aware deployment
* Upgrade handling
* Downgrade protection
* Deployment staging
* Validation before activation
* Persistent-data preservation
* Runtime uninstall

Installing or updating ProfMig does **not** automatically start a profile migration.

Persistent runtime data includes:

```text
Logs
Reports
Backup
```

These directories are preserved by the standard uninstall and upgrade processes.

For detailed deployment behaviour, see:

[`docs/Deployment-and-Update-Strategy.md`](docs/Deployment-and-Update-Strategy.md)

---

## Microsoft Intune deployment

ProfMig can be packaged as a Microsoft Intune Win32 application.

The Intune build process creates a version-linked Win32 package and detection script.

### Win32 package

```text
dist\Intune\Package\ProfMig-<version>.intunewin
```

Current version example:

```text
ProfMig-0.5.0.intunewin
```

### Detection script

```text
dist\Intune\Detection\Detect-ProfMig-<version>.ps1
```

Current version example:

```text
Detect-ProfMig-0.5.0.ps1
```

Detection validates:

* Installed build metadata
* Expected application version
* Required ProfMig runtime entry point

An installation is therefore not considered healthy solely because `ProfMig.Build.psd1` remains present.

### Validated lifecycle

The Intune-style deployment lifecycle has been validated locally and under Windows SYSTEM context for:

* Runtime installation
* Exact-version detection
* Incorrect-version rejection
* Runtime presence validation
* Incomplete-installation detection
* Runtime uninstall
* Detection after uninstall
* Persistent-data preservation
* Upgrade handling
* Runtime replacement

Sprint 5.5 validated the controlled upgrade path:

```text
0.1.0 -> 0.2.0
```

This historical version remains documented because it represents the actual upgrade validation that was performed.

### Managed-device status

Actual Microsoft Intune Win32 deployment to a managed test endpoint remains:

```text
PENDING
```

This is an environment-dependent integration test and is intentionally not represented as completed.

For complete Intune guidance, see:

[`docs/Microsoft-Intune-Deployment.md`](docs/Microsoft-Intune-Deployment.md)

---

## SYSTEM execution

ProfMig has been validated under:

```text
NT AUTHORITY\SYSTEM
```

SYSTEM-context validation includes both deployment operations and unattended silent migration.

Validated migration behaviour includes:

* Source and destination profile resolution
* Pre-migration validation
* Destination ACL validation
* Minimal profile migration
* Desktop and Documents migration
* SHA256 verification of copied test data
* Logging
* Reporting
* Process exit-code propagation

SYSTEM execution does not bypass normal ProfMig migration controls.

Deployment and actual profile migration remain separate operational workflows.

---

## Remote and RMM execution

ProfMig supports vendor-neutral execution through Remote Monitoring and Management platforms and other remote-management systems.

Management-platform-specific behaviour is intentionally kept outside the ProfMig core.

Remote execution supports:

* Silent deployment
* Silent migration
* External configuration
* Command-line parameters
* SYSTEM execution
* Administrator execution
* 64-bit PowerShell
* Working-directory-independent execution
* Predictable exit codes
* Local logging
* Report generation
* Remote result interpretation

A vendor-neutral wrapper is available under:

```text
examples\remote-deployment\
```

The wrapper preserves ProfMig process exit codes so the calling management platform can interpret the result.

Temporary deployment and cleanup behaviour remain the responsibility of the calling management platform where appropriate.

For detailed guidance, see:

[`docs/Remote-Execution-and-RMM-Deployment.md`](docs/Remote-Execution-and-RMM-Deployment.md)

---

## Code signing and release integrity

ProfMig supports Authenticode signing of executable PowerShell runtime content.

Release-integrity controls combine two mechanisms:

### Authenticode

Executable PowerShell content can be signed using a trusted code-signing certificate.

Signature validation can detect:

* Modified scripts
* Invalid signatures
* Unsigned executable content where signing is required

### SHA256 package integrity

ProfMig can generate and validate a SHA256 manifest for the runtime package.

This protects content that is not necessarily Authenticode signed, including configuration and supporting files.

Integrity validation can detect:

* Modified files
* Missing files
* Unexpected files
* Hash mismatches

Using Authenticode and SHA256 together provides executable-code authenticity and complete package-integrity validation.

Tamper testing has confirmed detection of both modified executable PowerShell content and modified non-executable configuration content.

---

## Versioning

ProfMig uses semantic versioning for published releases.

The application version is defined in:

```text
src\Config.psd1
```

Current development version:

```text
0.5.0
```

The configuration schema version is independent from the application version.

For example:

```text
Application.Version = 0.5.0
SchemaVersion       = 1.0
```

Runtime builds generate:

```text
ProfMig.Build.psd1
```

Generated metadata is used for:

* Runtime identification
* Deployment validation
* Installed-version detection
* Upgrade decisions
* Downgrade protection
* Intune detection
* Release traceability

The same configured application version is used when generating runtime and Intune deployment artifacts.

For additional information, see:

[`docs/Versioning-and-Build-Information.md`](docs/Versioning-and-Build-Information.md)

---

## Safety principles

Migration safety is a core ProfMig design principle.

Current controls include:

* Source and destination profiles cannot be the same
* Invalid profile relationships can block migration
* Required administrative privileges are validated
* Destination storage capacity is validated
* A configurable storage safety margin is applied
* Existing destination files are not overwritten
* Missing source folders do not unnecessarily terminate migration
* Locked files use bounded retry behaviour
* File-access failures are classified and recorded
* Failed copy operations are not reported as successful
* Skipped files remain visible in migration results
* Central exclusions prevent unsafe data from being copied
* Mandatory security exclusions override generic include rules
* Known credential stores and protected credential data are excluded
* ProfMig does not attempt to decrypt protected credentials
* Browser authentication state is not intentionally migrated
* Outlook OST files are not migrated
* Source data is never deleted by migration
* Source ACLs remain unchanged
* Destination ACLs can be validated and repaired using scoped permissions
* Permission repair does not introduce `Everyone: Full Control`
* Critical errors can stop unsafe migration
* Recoverable failures can use controlled retry, skip or continue behaviour
* Migrated files can be verified after copy
* Optional SHA256 verification can detect content differences
* Sensitive credential-like values are redacted from logs and reports
* Deployment does not automatically initiate migration
* Endpoint deployment does not bypass migration validation
* RMM execution does not bypass migration validation
* SYSTEM ownership of a destination user profile is never assumed
* ProfMig does not rely on globally weakening Windows security controls

These controls form the reliability and security baseline for future ProfMig development.

---

## Testing

ProfMig contains automated and manual tests covering migration, reliability, security, packaging, deployment and automation.

### Milestone 3 regression

The reusable M3 suite contains:

```text
47 tests
47 passed
0 failed
```

Coverage includes:

* Profile validation
* Privilege validation
* Storage validation
* File handling
* Permissions and ACLs
* Recovery and error handling
* Migration verification
* Security behaviour
* Logging
* Reporting

Run:

```powershell
& '.\tests\M3\Invoke-M3Tests.ps1'
```

Formal Milestone 3 acceptance additionally consisted of 51 validation scenarios, all of which passed.

Detailed evidence is documented in:

[`docs/M3-Security-Reliability-Test-Plan.md`](docs/M3-Security-Reliability-Test-Plan.md)

### Milestone 5 regression

Milestone 5 has a central validation runner:

```powershell
& '.\tests\M5\Invoke-M5Tests.ps1'
```

Current result:

```text
Suites : 13
Passed : 13
Failed : 0
```

The runner covers:

* Packaging
* Versioning
* Command-line and silent mode
* Deployment
* Uninstall
* Intune detection
* Remote configuration
* Remote execution
* Remote exit codes
* Remote results
* Remote wrapper
* Code signing and integrity
* Milestone 3 regression

Additional end-to-end validation covers:

* Standalone runtime execution
* Real silent migration
* External configuration
* Configured migration profiles
* SYSTEM execution
* Remote/RMM execution
* Local Intune lifecycle
* Signed runtime packages
* SHA256 package integrity
* Tamper detection

The Microsoft Intune managed-device validation remains pending.

Detailed Milestone 5 status is maintained in:

```text
tests\M5\M5-Validation-Matrix.md
```

---

## Requirements

Current runtime requirements:

* Windows 10 or Windows 11
* Windows Server 2019 or later where applicable
* Windows PowerShell 5.1
* 64-bit PowerShell for supported unattended workflows
* Local administrative privileges where required by the operation

ProfMig is primarily developed and validated using Windows PowerShell 5.1.

The current M3 regression suite is compatible with Pester 3.4.

Microsoft Intune deployment additionally requires:

* A supported Microsoft Intune Win32 application environment
* Intune Management Extension on the managed endpoint

The Microsoft Win32 Content Prep Tool is required only on the build workstation when generating `.intunewin` packages and is not part of the ProfMig endpoint runtime.

Code signing requires an appropriate trusted code-signing certificate and access to its private key during the signing process.

---

## Roadmap

### M1 – Core Migration Engine

**Status: Completed**

* [x] Core framework
* [x] Configuration
* [x] Logging
* [x] Interactive menu
* [x] Windows profile inventory
* [x] Core profile Copy Engine
* [x] Migration Reporting Engine

---

### M2 – Application Migration

**Status: Completed**

* [x] Application detection framework
* [x] Microsoft Edge migration
* [x] Google Chrome migration
* [x] Microsoft Outlook migration
* [x] Generic application migration framework
* [x] Central application exclusions
* [x] Application migration integration
* [x] End-to-end application migration validation

---

### M3 – Reliability & Security

**Status: Completed and approved**

* [x] Profile validation
* [x] Privilege validation
* [x] Storage and capacity validation
* [x] File-access and locked-file handling
* [x] Destination permissions and ACL handling
* [x] Structured error handling
* [x] Recovery behaviour
* [x] Migration verification
* [x] Optional hash-based verification
* [x] Security validation
* [x] Sensitive-data protection in logging and reporting
* [x] Migration reporting validation
* [x] Formal M3 security and reliability validation
* [x] Reusable automated M3 regression suite
* [x] Manual/hybrid regression procedures

Formal result:

```text
51/51 PASS
M3 status: APPROVED
```

Automated regression:

```text
47/47 PASS
```

---

### M5 – Deployment & Operations

**Status: Final validation**

* [x] Runtime packaging
* [x] Application structure for deployment
* [x] Command-line operation
* [x] Silent and non-interactive operation
* [x] Migration profile configuration
* [x] External configuration
* [x] Version and build metadata
* [x] Controlled deployment
* [x] Runtime uninstall
* [x] Persistent-data preservation
* [x] Version-aware deployment
* [x] Downgrade protection
* [x] Microsoft Intune source packaging
* [x] Microsoft Intune Win32 package generation
* [x] Version-specific Intune detection
* [x] Incomplete-installation detection
* [x] SYSTEM-context runtime installation
* [x] SYSTEM-context runtime detection
* [x] SYSTEM-context runtime uninstall
* [x] SYSTEM-context runtime upgrade
* [x] SYSTEM-context migration
* [x] Vendor-neutral RMM and remote deployment
* [x] Remote configuration validation
* [x] Remote exit-code propagation
* [x] Remote result interpretation
* [x] Code signing
* [x] Execution-security validation
* [x] SHA256 release-package integrity
* [x] Package tamper detection
* [x] Milestone 5 automated regression
* [x] Standalone deployment validation
* [x] Silent migration validation
* [x] Remote/RMM end-to-end validation
* [x] Local Intune lifecycle validation
* [ ] Microsoft Intune managed-device deployment validation
* [ ] Final M5 acceptance

Current automated result:

```text
M5: 13/13 PASS
M3: 47/47 PASS
```

The remaining managed-device Intune validation is environment-dependent and intentionally remains pending.

---

## Future direction

The modular architecture and validated reliability baseline are intended to support future functionality such as:

* Additional Windows profile components
* Additional application definitions
* Additional browser migration capabilities
* Outlook migration enhancements
* OneDrive migration
* Extended backup and rollback capabilities
* Graphical user interface
* Machine-readable reports
* Additional endpoint-management integrations
* Centralized reporting
* Additional release automation

These items represent project direction and should not be considered implemented until their corresponding development work is completed.

---

## Deployment model

A key ProfMig design principle is the separation between application deployment and migration execution.

```text
Endpoint management / RMM
            |
            v
Install / update ProfMig runtime
            |
            v
Validate installed runtime
            |
            v
ProfMig available on endpoint
            |
            +-----------------------------+
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

This allows the runtime to be staged on managed endpoints before migration is scheduled.

SYSTEM has been validated for both runtime deployment and unattended silent migration.

These remain separate workflows and retain their own validation and result handling.

---

## Documentation

Technical documentation is available in the `docs` directory.

Key documents include:

* [Packaging and Application Structure](docs/Packaging-and-Application-Structure.md)
* [Command-Line and Silent Mode](docs/Command-Line-and-Silent-Mode.md)
* [Configuration and Migration Profiles](docs/Configuration-and-Migration-Profiles.md)
* [Deployment and Update Strategy](docs/Deployment-and-Update-Strategy.md)
* [Microsoft Intune Deployment](docs/Microsoft-Intune-Deployment.md)
* [Remote Execution and RMM Deployment](docs/Remote-Execution-and-RMM-Deployment.md)
* [Versioning and Build Information](docs/Versioning-and-Build-Information.md)
* [Error Handling and Recovery](docs/Error-Handling-and-Recovery.md)
* [M3 Security and Reliability Test Plan](docs/M3-Security-Reliability-Test-Plan.md)

---

## Contributing

Contributions are welcome.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for contribution guidelines.

---

## Security

Security issues should be reported according to the process described in [`SECURITY.md`](SECURITY.md).

ProfMig intentionally avoids migrating known credentials, authentication tokens and other security-sensitive application state where this data cannot be migrated safely.

Security and migration validation remain active regardless of whether ProfMig is started interactively, silently, as SYSTEM, through RMM or through an endpoint-management workflow.

---

## License

ProfMig is licensed under the MIT License.

See [`LICENSE`](LICENSE) for details.

---

## Maintainers

ProfMig is maintained by:

* Remco de Kievit ([@scorpido74](https://github.com/scorpido74))
* Bas van Ek ([@baseman-dev](https://github.com/baseman-dev))
