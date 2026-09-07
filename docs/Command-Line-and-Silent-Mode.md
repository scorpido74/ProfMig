# ProfMig Command-Line and Silent Mode

## Overview

ProfMig supports both interactive and unattended migration.

Interactive mode provides the existing menu-driven PowerShell interface.

Silent mode allows ProfMig to perform a complete profile migration without interactive user input. This makes ProfMig suitable for automated deployment and migration scenarios using management platforms such as Microsoft Intune, RMM solutions, software deployment systems, or PowerShell automation.

Silent mode reuses the existing ProfMig migration, validation, permission, verification, logging, reporting, and structured error-handling functionality.

It does not implement a separate migration or error-handling path.

---

## Execution Modes

### Interactive Mode

When ProfMig is started without the `-Silent` parameter, the existing interactive menu is displayed.

Example:

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File .\src\ProfMig.ps1
```

Interactive behavior remains unchanged.

### Silent Mode

Silent mode is enabled using:

```text
-Silent
```

When silent mode is enabled:

- No migration menu is displayed.
- Source and destination profiles must be supplied through command-line parameters.
- Profile selection does not require user interaction.
- Existing pre-migration validation is executed.
- Existing security and permission checks remain active.
- The existing Copy Engine is used.
- Verification remains enabled according to the ProfMig configuration.
- Logging remains enabled.
- A migration report is generated.
- The process terminates with a defined ProfMig exit code.
- No migration step waits for interactive user input.

---

## Profile Identification

Windows profile names are not considered sufficiently unique for automated migration.

This is particularly important during Microsoft Entra ID or tenant migration scenarios where a user may receive the same visible username while the Windows security principal and SID have changed.

ProfMig therefore supports profile identification using either:

1. Windows SID
2. Local Windows profile path

SID-based identification is preferred for automation where the source and destination SIDs are known.

---

## Silent Migration Using SIDs

Example:

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File .\src\ProfMig.ps1 `
    -Silent `
    -SourceSid 'S-1-5-21-1111111111-2222222222-3333333333-1001' `
    -DestinationSid 'S-1-5-21-1111111111-2222222222-3333333333-1002'
```

ProfMig resolves both SIDs against the Windows profile inventory before migration starts.

If either SID cannot be resolved, the migration is stopped with a structured validation error.

---

## Silent Migration Using Profile Paths

Profiles can alternatively be identified using their local Windows profile paths.

Example:

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File .\src\ProfMig.ps1 `
    -Silent `
    -SourceProfilePath 'C:\Users\SourceUser' `
    -DestinationProfilePath 'C:\Users\DestinationUser'
```

Profile-path matching is case-insensitive.

Both paths must resolve to existing Windows profiles known to ProfMig.

---

## Parameter Rules

Source and destination identifiers must use the same identification method.

Valid combinations are:

```text
-SourceSid
-DestinationSid
```

or:

```text
-SourceProfilePath
-DestinationProfilePath
```

SID and profile-path parameters must not be mixed.

The following example is invalid:

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File .\src\ProfMig.ps1 `
    -Silent `
    -SourceSid 'S-1-5-21-...' `
    -DestinationProfilePath 'C:\Users\DestinationUser'
```

Invalid or incomplete parameter combinations produce a structured ProfMig configuration error and a defined process exit code.

---

## Command-Line Parameters

### `-Silent`

Enables unattended migration.

```text
-Silent
```

Without this parameter ProfMig starts in interactive mode.

---

### `-SourceSid`

Specifies the SID of the source Windows profile.

Example:

```text
-SourceSid 'S-1-5-21-1111111111-2222222222-3333333333-1001'
```

Must be used together with `-DestinationSid`.

---

### `-DestinationSid`

Specifies the SID of the destination Windows profile.

Example:

```text
-DestinationSid 'S-1-5-21-1111111111-2222222222-3333333333-1002'
```

Must be used together with `-SourceSid`.

---

### `-SourceProfilePath`

Specifies the source Windows profile path.

Example:

```text
-SourceProfilePath 'C:\Users\SourceUser'
```

Must be used together with `-DestinationProfilePath`.

---

### `-DestinationProfilePath`

Specifies the destination Windows profile path.

Example:

```text
-DestinationProfilePath 'C:\Users\DestinationUser'
```

Must be used together with `-SourceProfilePath`.

---

### `-ConfigPath`

Specifies an alternative ProfMig configuration file.

Example:

```text
-ConfigPath 'C:\ProgramData\ProfMig\Config.psd1'
```

When this parameter is not supplied, ProfMig uses its standard configuration:

```text
src\Config.psd1
```

The configuration can be used to control migration behavior without modifying the ProfMig runtime files.

For example, a configuration can specify the profile folders that should be migrated:

```powershell
Folders = @(
    'Desktop'
    'Documents'
    'Pictures'
)
```

When no explicit folder selection is configured, ProfMig uses its standard profile folder selection.

---

### `-LogPath`

Overrides the configured ProfMig log location.

Example:

```text
-LogPath 'C:\ProgramData\ProfMig\Logs'
```

This is useful when an automation or management platform requires logs to be stored in a specific location.

---

### `-ReportPath`

Overrides the configured ProfMig report location.

Example:

```text
-ReportPath 'C:\ProgramData\ProfMig\Reports'
```

Migration reports are written to this location.

---

### `-SkipApplications`

Disables application-data migration for the current migration.

Example:

```text
-SkipApplications
```

Profile migration, validation, permissions, verification, logging, and reporting continue to operate normally.

This option can be useful when application data is migrated separately or when only Windows profile data is required.

---

## Configuration Example

The following example performs a silent migration using profile paths, an alternative configuration, and dedicated log and report locations:

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File .\src\ProfMig.ps1 `
    -Silent `
    -SourceProfilePath 'C:\Users\SourceUser' `
    -DestinationProfilePath 'C:\Users\DestinationUser' `
    -ConfigPath 'C:\ProgramData\ProfMig\Config.psd1' `
    -LogPath 'C:\ProgramData\ProfMig\Logs' `
    -ReportPath 'C:\ProgramData\ProfMig\Reports'
```

---

## Profile-Only Migration Example

Application migration can be skipped:

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File .\src\ProfMig.ps1 `
    -Silent `
    -SourceProfilePath 'C:\Users\SourceUser' `
    -DestinationProfilePath 'C:\Users\DestinationUser' `
    -SkipApplications
```

---

## Validation

Silent mode does not bypass ProfMig validation.

Before migration starts, ProfMig performs the existing pre-migration validation process.

This includes checks such as:

- Source profile validation
- Destination profile validation
- Profile identity validation
- Source and destination accessibility
- Administrator context
- Registry access
- Configuration validation
- Destination storage capacity
- Critical migration conditions

If validation determines that migration cannot safely continue, ProfMig stops the migration and returns the corresponding structured exit code.

---

## Source and Destination Protection

ProfMig prevents invalid profile combinations.

The following conditions are rejected:

- Source profile cannot be resolved.
- Destination profile cannot be resolved.
- Source and destination paths are identical.
- Source and destination SIDs are identical.
- Source profile is inaccessible.
- Destination profile is inaccessible.
- Required source or destination parameters are missing.
- SID and profile-path identification methods are mixed.

These conditions are handled through the existing ProfMig structured error model.

---

## Application Migration

Unless `-SkipApplications` is specified, ProfMig performs application discovery for the selected source profile.

Detected supported applications can then participate in the existing ProfMig application migration process.

Internal ProfMig test application definitions are excluded from normal silent migration.

Application migration uses the existing ProfMig application framework and does not implement a separate silent-mode migration engine.

---

## Logging

Silent migrations always use the existing ProfMig logging framework.

The log records important migration events including:

- ProfMig startup
- Profile inventory
- Source and destination resolution
- Validation
- Migration start
- Permission and ACL validation
- Application migration
- Migration completion
- Report generation
- Final process exit code

A custom log location can be supplied using `-LogPath`.

---

## Reporting

Silent migrations generate the same ProfMig migration reports used by the existing migration framework.

Reports include information such as:

- Source profile
- Destination profile
- Migration duration
- Selected profile components
- Files copied
- Files skipped
- Files excluded
- Failed files
- Verification results
- Application migration results
- Warnings
- Errors
- Overall migration status

A custom report location can be supplied using `-ReportPath`.

---

## Verification

Silent mode uses the existing ProfMig verification framework.

Verification behavior is controlled through the ProfMig configuration.

Example:

```powershell
Verification = @{
    Level         = 'Standard'
    HashAlgorithm = 'SHA256'
}
```

Verification failures are processed through the existing ProfMig structured error and exit-code model.

Silent mode does not disable or bypass verification.

---

## Exit Codes

ProfMig silent mode reuses the structured exit-code model introduced during Milestone 3.

`Get-ProfMigExitCode` remains the central mechanism for translating ProfMig result categories into process exit codes.

No separate silent-mode exit-code model is maintained.

| Exit code | Result |
|---:|---|
| 0 | Success |
| 1 | Success with warnings |
| 2 | Migration failed |
| 3 | Configuration error |
| 4 | Validation error |
| 5 | Permission or security error |
| 6 | Insufficient storage |
| 7 | Verification error |
| 8 | Application migration error |
| 99 | Unexpected critical error |

Automation platforms can use these values to determine the result of an unattended migration.

Example:

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File .\src\ProfMig.ps1 `
    -Silent `
    -SourceProfilePath 'C:\Users\SourceUser' `
    -DestinationProfilePath 'C:\Users\DestinationUser'

$ExitCode = $LASTEXITCODE

Write-Host "ProfMig exit code: $ExitCode"

exit $ExitCode
```

---

## Success with Warnings

A migration can complete successfully while still producing warnings.

Examples include:

- A destination file already exists.
- A Windows reparse point is intentionally not traversed.
- A non-critical item is skipped.
- A non-critical validation warning is detected.

In this situation ProfMig can return:

```text
Overall result : Success with warnings
Exit code      : 1
```

This allows automation systems to distinguish a completely clean migration from a migration that completed successfully but requires review.

---

## Microsoft Entra ID Tenant Migration

Silent mode is designed to support scenarios where a Windows device is moved between Microsoft Entra ID tenants.

The source and destination users can have the same visible username while representing different Windows security principals.

For example:

```text
Source:
SID  = S-1-12-1-...
Path = C:\Users\User

Destination:
SID  = S-1-12-1-...
Path = C:\Users\User.001
```

For this reason ProfMig does not rely on the visible profile name as the unique profile identifier.

SID or full profile path should be used for unattended migration.

---

## Automation Example

A management platform can execute ProfMig and evaluate the returned process exit code.

```powershell
$ProfMig = 'C:\Program Files\ProfMig\src\ProfMig.ps1'

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $ProfMig `
    -Silent `
    -SourceProfilePath 'C:\Users\SourceUser' `
    -DestinationProfilePath 'C:\Users\DestinationUser' `
    -LogPath 'C:\ProgramData\ProfMig\Logs' `
    -ReportPath 'C:\ProgramData\ProfMig\Reports'

$ProfMigExitCode = $LASTEXITCODE

switch ($ProfMigExitCode) {

    0 {
        Write-Output 'ProfMig migration completed successfully.'
    }

    1 {
        Write-Output 'ProfMig migration completed with warnings.'
    }

    default {
        Write-Error "ProfMig migration failed with exit code $ProfMigExitCode."
    }
}

exit $ProfMigExitCode
```

This pattern can be used by Microsoft Intune, RMM platforms, deployment tools, or other management systems.

---

## Security Considerations

Command-line parameters must never contain passwords, authentication tokens, API keys, or other secrets.

ProfMig silent mode is designed to operate using Windows profile identifiers and local configuration only.

Existing ProfMig security controls remain active during unattended execution.

Silent mode does not bypass:

- Administrator requirements
- Profile accessibility checks
- Destination permission validation
- ACL handling
- Storage validation
- Verification
- Structured error handling

---

## Operational Recommendations

For automated migrations:

1. Run ProfMig from an elevated administrative context.
2. Prefer SID-based profile identification when the source and destination SIDs are known.
3. Use full profile paths when SID information is not available to the automation platform.
4. Store logs and reports in locations accessible to the management platform.
5. Evaluate the ProfMig process exit code after every migration.
6. Treat exit code `1` as a successful migration with warnings that may require review.
7. Review migration reports before removing the original source profile.
8. Test configuration changes before large-scale deployment.
9. Do not include credentials or secrets in ProfMig command-line parameters.

---

## Tested Scenario

Sprint 5.2 validation included a complete unattended profile migration using profile-path identification.

The validation demonstrated:

- Source and destination profile resolution without interactive input.
- Configuration supplied programmatically.
- Pre-migration validation.
- Profile data migration through the existing Copy Engine.
- Destination ACL validation.
- Verification of copied files.
- Migration reporting.
- Structured warning handling.
- Correct process exit code.
- No interactive migration prompts.

The test completed as:

```text
Overall result          : Success with warnings
Copy Engine status      : CompletedWithWarnings
Application Migration   : NotRun
Process exit code       : 1
```

All copied test data was independently compared between source and destination using SHA-256 and was identical.

---

## Backward Compatibility

The introduction of silent mode does not replace the existing interactive ProfMig workflow.

Starting ProfMig without `-Silent` continues to use the interactive menu.

This allows the same ProfMig codebase to support both:

- Technician-driven interactive migrations
- Automated unattended migrations

Both execution modes use the existing ProfMig core components.

---

## Related Components

Silent mode integrates with the existing ProfMig components including:

- Configuration
- Inventory
- Validation
- Copy Engine
- Permissions and ACL handling
- Application migration
- Verification
- Logging
- Reporting
- Structured error handling
- Exit-code handling

This keeps automated execution aligned with the existing ProfMig architecture and avoids maintaining a separate migration implementation.