# Changelog

All notable changes to ProfMig are documented in this file.

ProfMig follows semantic versioning for published releases.

---

## [v0.5.0] - 2026-09-14

### Added

#### Deployment and packaging

* Added standalone ProfMig runtime packaging.
* Added deployment and uninstall tooling.
* Added package build metadata.
* Added support for persistent Logs, Reports and Backup directories.
* Added predictable installation, upgrade and uninstall behaviour.
* Added Microsoft Intune Win32 package generation.
* Added version-specific Intune detection script generation.
* Added Intune detection of incomplete runtime installations.

#### Command-line and automation

* Added command-line and silent migration mode.
* Added source and destination profile selection through command-line parameters.
* Added migration profile selection through command-line parameters.
* Added external configuration file support for unattended migration.
* Added predictable process exit codes for deployment and management platforms.
* Added unattended launcher support with argument and exit-code propagation.

#### Migration profiles and configuration

* Added configurable migration profiles.
* Added `Standard` migration profile.
* Added `Minimal` migration profile.
* Added configurable default migration profile selection.
* Added explicit command-line migration profile precedence over the configured default.
* Added configuration schema validation.
* Added validation of unsupported configuration values.

#### Remote and RMM execution

* Added vendor-neutral remote execution wrapper.
* Added support for LocalSystem execution.
* Added support for administrator and remote-management execution contexts.
* Added native 64-bit PowerShell resolution from 32-bit management processes.
* Added working-directory-independent remote execution.
* Added remote exit-code propagation.
* Added persistent remote logging and reporting.
* Added remote result interpretation and validation guidance.

#### Code signing and release integrity

* Added Authenticode signing support for ProfMig PowerShell runtime files.
* Added support for trusted code-signing certificates with accessible private keys.
* Added SHA-256 package manifest generation.
* Added Authenticode signature validation tooling.
* Added SHA-256 package integrity validation tooling.
* Added detection of modified signed scripts.
* Added detection of modified, missing and unexpected package files.

#### Validation

* Added central Milestone 5 automated validation runner.
* Added Milestone 5 validation matrix.
* Added standalone package end-to-end validation.
* Added real silent migration validation.
* Added external configuration and default-profile validation.
* Added LocalSystem migration validation.
* Added remote/RMM migration validation.
* Added local Intune deployment lifecycle validation.
* Added signed package and tamper-detection validation.
* Added final Milestone 5 regression validation.

### Changed

* Changed ProfMig version from `0.2.0` to `0.5.0`.
* Improved launcher behaviour for unattended execution.
* Improved migration profile resolution to use configured default profiles.
* Improved Intune detection to validate the runtime entry point in addition to package metadata.
* Improved deployment architecture to keep management-platform-specific behaviour outside the ProfMig core.
* Improved release integrity through complementary Authenticode and SHA-256 validation.
* Expanded automated regression coverage for deployment, remote execution, Intune detection and configuration handling.

### Fixed

* Fixed `Start-ProfMig.bat` not forwarding command-line arguments.
* Fixed `Start-ProfMig.bat` always pausing after execution.
* Fixed launcher exit-code propagation during unattended execution.
* Fixed configured `Migration.DefaultProfile` being ignored when `-MigrationProfile` was not supplied.
* Fixed migration profile precedence so explicit command-line selection overrides the configured default.
* Fixed Intune detection incorrectly accepting an incomplete installation when version metadata remained but `src\ProfMig.ps1` was missing.

### Security

* Added Authenticode signing for executable PowerShell content.
* Added SHA-256 integrity validation for the complete runtime package.
* Added detection of executable-code tampering.
* Added integrity detection for non-executable package content such as configuration files.
* Added release integrity regression tests.
* Preserved existing credential-store exclusions and source ACL security controls through Milestone 3 regression validation.

### Validation

ProfMig v0.5.0 Milestone 5 technical validation completed successfully.

Final automated results:

* Milestone 5 suites: **13 passed, 0 failed**
* Milestone 3 regression tests: **47 passed, 0 failed**
* Versioning tests: **33 passed, 0 failed**
* Deployment tests: **33 passed, 0 failed**
* Remote configuration tests: **5 passed, 0 failed**
* Intune detection tests: **6 passed, 0 failed**
* Remote wrapper tests: **7 passed, 0 failed**
* Code signing and integrity tests: **6 passed, 0 failed**

End-to-end validation completed for:

* standalone runtime packaging;
* silent profile migration;
* external configuration and migration-profile selection;
* LocalSystem execution;
* remote/RMM execution;
* local Intune package lifecycle;
* Authenticode-signed package validation;
* SHA-256 package integrity;
* executable and non-executable tamper detection;
* final automated regression.

Actual Microsoft Intune Win32 deployment to a managed test device remains pending as an environment-dependent integration validation.

---

## [v0.2.0] - 2026-08-23

### Added

#### Application migration

- Added central application detection framework.
- Added Microsoft Edge profile migration.
- Added Google Chrome profile migration.
- Added Microsoft Outlook data migration.
- Added generic AppData migration framework.
- Added configurable application definitions.
- Added application selection to the interactive migration workflow.
- Added application-specific migration planning.
- Added application migration result tracking.

#### Microsoft Edge

- Added Edge installation and profile detection.
- Added migration of portable Edge profile data.
- Added bookmark migration.
- Added security-aware exclusion of non-portable browser data.
- Added Edge migration documentation.

#### Google Chrome

- Added Chrome installation and profile detection.
- Added support for multiple Chrome profiles.
- Added migration of portable Chrome profile data.
- Added security-aware exclusion of credentials, authentication data and other non-portable browser state.
- Added Chrome migration documentation.

#### Microsoft Outlook

- Added detection of classic Outlook and new Outlook.
- Added classic Outlook profile detection.
- Added PST migration.
- Added Outlook signature migration.
- Added Outlook template migration.
- Added Outlook navigation and print-settings migration.
- Added detection and exclusion of OST files.
- Added exclusion of profile-dependent Send/Receive settings.
- Added Outlook migration planning and validation.
- Added Outlook migration documentation.

#### Application exclusions

- Added central application exclusion engine.
- Added exclusions based on file name.
- Added exclusions based on directory name.
- Added exclusions based on relative path.
- Added exclusions based on file extension.
- Added application-specific exclusion rules.
- Added mandatory security exclusions.
- Added exclusion classification and reporting.

#### Validation

- Added central pre-migration validation framework.
- Added profile and privilege validation.
- Added application migration validation.
- Added validation of offline Windows profiles.
- Added validation of known-folder resolution.
- Added validation of application detection and migration availability.
- Added pre-migration validation documentation.

#### Repository and release management

- Added GitHub Actions validation workflow.
- Added automated GitHub release workflow.
- Added automated release package creation.
- Added release version validation against `src/Config.psd1`.
- Added PowerShell syntax validation to the CI workflow.
- Added release, build, issues and license badges to the README.
- Added repository governance and security documentation.
- Moved the MIT license to the repository root.
- Added official ProfMig version `0.2.0`.

### Changed

- Expanded the interactive migration workflow with application migration support.
- Expanded profile migration beyond standard Windows user folders.
- Improved Windows known-folder resolution for offline profiles.
- Improved application detection and migration planning.
- Updated README to reflect completion of M1 and M2.
- Updated security policy to use release-based support terminology.
- Changed ProfMig version from `1.0` development placeholder to `0.2.0`.

### Fixed

- Fixed Edge migration dependency loading for the central exclusion engine.
- Fixed Outlook migration dependency loading for the central exclusion engine.
- Fixed known-folder resolution for offline Windows profiles.
- Fixed copy-engine logging dependency so logging can be optional.
- Fixed generic application migration incorrectly blocking applications that are not detected.
- Fixed Outlook detection when exclusion dependencies were not loaded.
- Fixed application migration integration issues discovered during Sprint 2.8 validation.

### Security

- Added mandatory security exclusions for unsafe or non-portable application data.
- Prevented migration of known credential and authentication data where migration cannot be performed safely.
- Prevented Outlook OST files from being migrated.
- Prevented profile-dependent Outlook data from being treated as portable.
- Added security-aware application migration classifications.
- Added repository security reporting policy.

### Validation

ProfMig v0.2.0 was validated end-to-end using real Windows user profiles.

Validated components include:

- Windows profile migration.
- Windows known-folder handling.
- Central exclusion processing.
- Generic application migration.
- Microsoft Edge migration.
- Google Chrome migration.
- Microsoft Outlook migration.
- Migration reporting.
- Pre-migration validation.

Application migration was verified between separate Windows user profiles, including verification that portable application data was migrated while known excluded and security-sensitive data was not copied.

---

## [v0.1.0] - 2026-08

### Added

#### Core framework

- Added initial ProfMig project structure.
- Added modular PowerShell architecture.
- Added central configuration framework.
- Added ProfMig initialization framework.
- Added environment validation.
- Added operational logging framework.

#### Profile inventory

- Added Windows user profile discovery.
- Added profile inventory based on the Windows ProfileList registry.
- Added source and destination profile selection.
- Added detection of relevant Windows profile folders.
- Added filtering of system and excluded profiles.

#### Migration engine

- Added core Windows profile copy engine.
- Added migration support for:
  - Desktop
  - Documents
  - Downloads
  - Pictures
- Added source and destination validation.
- Added protection against overwriting existing destination files.
- Added file exclusion handling.
- Added tracking of copied, skipped, excluded and failed files.
- Added migration byte and file statistics.

#### Reporting

- Added structured migration results.
- Added human-readable migration reports.
- Added migration status classification.
- Added reporting of skipped, excluded and failed items.
- Added migration duration and statistics reporting.

#### User interface

- Added interactive PowerShell menu.
- Added source profile selection.
- Added destination profile selection.
- Added migration configuration overview.
- Added migration confirmation workflow.

#### Project governance

- Added README documentation.
- Added contribution guidelines.
- Added code of conduct.
- Added security policy.
- Added MIT license.

---

## Unreleased

Development after v0.2.0 is tracked through GitHub Issues and Milestones.

Planned work includes additional migration validation, migration safety capabilities, backup and rollback functionality, additional application migration capabilities, automation and future user-interface improvements.
