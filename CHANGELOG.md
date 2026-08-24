# Changelog

All notable changes to ProfMig are documented in this file.

ProfMig follows semantic versioning for published releases.

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
