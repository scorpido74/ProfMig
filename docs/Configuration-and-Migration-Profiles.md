# ProfMig Configuration and Migration Profiles

## Overview

ProfMig uses PowerShell data files (`.psd1`) for configuration.

The central configuration file is:

```text
src\Config.psd1
```

Sprint 5.3 extends the existing ProfMig configuration architecture with reusable migration profiles. Migration profiles do not replace `Config.psd1`. Instead, they define migration-specific selections that are validated and merged with the central ProfMig configuration before a migration starts.

This allows administrators to maintain safe global defaults while using reusable profiles for different migration scenarios.

---

## Configuration Architecture

ProfMig uses two configuration layers:

1. **Global configuration**
   Defines application-wide defaults and safety settings.

2. **Migration profile**
   Defines the components and applications required for a specific type of migration.

The effective migration configuration is created by merging the selected migration profile with the global configuration.

Global security, retry, storage, verification, logging, and reporting settings remain available unless a supported migration-profile setting explicitly overrides them.

Migration profiles are validated before they are used.

---

## Configuration Format

ProfMig configuration files use the PowerShell Data File (`.psd1`) format.

PSD1 was retained because it is:

- Human-readable
- Native to PowerShell
- Suitable for source control
- Suitable for automated deployment
- Already used by ProfMig
- Capable of representing the configuration structures required by ProfMig

No second configuration format is introduced by Sprint 5.3.

Configuration files must not contain passwords, authentication tokens, API keys, or other secrets.

---

## Configuration Schema

The current ProfMig configuration schema is:

```powershell
SchemaVersion = '1.0'
```

Migration profiles also use:

```powershell
SchemaVersion = '1.0'
```

ProfMig validates supported schema versions before migration.

An unsupported schema version produces a structured `ConfigurationError` and stops processing.

For backward compatibility, existing ProfMig global configurations without `SchemaVersion` remain supported as legacy configuration.

Migration profiles require an explicit supported schema version.

---

## Global Configuration

The default configuration is stored in:

```text
src\Config.psd1
```

The configuration contains the following main sections.

### Application

```powershell
Application = @{
    Name    = 'ProfMig'
    Version = '0.2.0'
    Build   = 'Development'
}
```

Contains ProfMig application metadata.

---

### Paths

```powershell
Paths = @{
    Logs                   = 'Logs'
    Reports                = 'Reports'
    Backup                 = 'Backup'
    ApplicationDefinitions = 'Applications'
    MigrationProfiles      = 'Profiles'
}
```

`MigrationProfiles` specifies the default location for reusable migration profiles relative to the ProfMig source directory.

---

### Migration

```powershell
Migration = @{
    DefaultProfile = 'Standard'

    Components = @(
        'Desktop'
        'Documents'
        'Downloads'
        'Pictures'
        'Music'
        'Videos'
        'Favorites'
        'Links'
    )

    Applications = @{
        Enabled = $true
    }
}
```

Defines the standard migration selections and migration-profile metadata.

`DefaultProfile` identifies the standard reusable profile. Explicit profile selection in silent mode is performed using the `-MigrationProfile` command-line parameter.

The `Components` collection documents the standard ProfMig component selection.

---

## Supported Migration Components

Migration profiles can select the following profile components:

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

Unsupported component names are rejected during profile validation.

---

## Application Migration

Global application migration is enabled by default:

```powershell
Migration = @{
    Applications = @{
        Enabled = $true
    }
}
```

Migration profiles can further control application migration.

Supported native application identifiers are:

```text
Microsoft.Edge
Google.Chrome
Microsoft.Outlook
```

Example:

```powershell
Applications = @{
    Enabled = $true

    Include = @(
        'Microsoft.Edge'
        'Google.Chrome'
        'Microsoft.Outlook'
    )
}
```

If application migration is disabled by a migration profile, application discovery and migration are skipped for that migration.

The command-line `-SkipApplications` option can also disable application migration for an individual silent-mode execution.

---

## Retry Configuration

ProfMig uses centralized retry settings:

```powershell
Retry = @{
    Count        = 3
    DelaySeconds = 2
}
```

`Count` specifies the configured retry count.

Valid values:

```text
0 through 10
```

`DelaySeconds` specifies the delay between retries.

Valid values:

```text
0 through 60
```

These settings are propagated to the ProfMig Copy Engine and supported application migration paths.

Invalid values produce a structured configuration error.

---

## Storage Validation

Storage safety settings are configured centrally:

```powershell
Validation = @{
    Storage = @{
        SafetyMarginPercent     = 20
        WarningRemainingPercent = 15
    }
}
```

`SafetyMarginPercent` reserves additional capacity when ProfMig calculates the required destination storage.

`WarningRemainingPercent` defines the remaining-capacity threshold at which ProfMig can report a storage warning.

Valid percentage values are:

```text
0 through 100
```

Migration profiles retain the central storage-safety configuration.

---

## Verification

Default verification configuration:

```powershell
Verification = @{
    Level         = 'Standard'
    HashAlgorithm = 'SHA256'
}
```

Supported verification levels are:

```text
Standard
Hash
```

Supported hash algorithms are:

```text
SHA256
SHA384
SHA512
```

A migration profile can override the verification level.

Example:

```powershell
Verification = @{
    Level = 'Hash'
}
```

Settings not overridden by the migration profile, such as `HashAlgorithm`, remain inherited from the global configuration.

---

## Excluded Profiles

ProfMig centrally maintains profiles that must not normally be selected as migration users.

Default exclusions include:

```text
All Users
Default
Default User
Public
defaultuser0
WDAGUtilityAccount
Administrator
systemprofile
LocalService
NetworkService
```

Migration profiles do not disable these exclusions.

This prevents reusable migration profiles from casually bypassing existing profile-selection safety controls.

---

# Migration Profiles

## Profile Location

Built-in migration profiles are stored in:

```text
src\Profiles
```

The default location is configured through:

```powershell
Paths = @{
    MigrationProfiles = 'Profiles'
}
```

---

## Standard Migration Profile

The built-in Standard profile is:

```text
src\Profiles\Standard.psd1
```

It enables the standard user-profile components and supported application migration.

Example:

```powershell
@{
    SchemaVersion = '1.0'

    Profile = @{
        Name        = 'Standard'
        Description = 'Standard user migration profile.'
    }

    Components = @(
        'Desktop'
        'Documents'
        'Downloads'
        'Pictures'
        'Music'
        'Videos'
        'Favorites'
        'Links'
    )

    Applications = @{
        Enabled = $true

        Include = @(
            'Microsoft.Edge'
            'Google.Chrome'
            'Microsoft.Outlook'
        )
    }

    Verification = @{
        Level = 'Standard'
    }
}
```

---

## Minimal Migration Profile

The built-in Minimal profile is:

```text
src\Profiles\Minimal.psd1
```

It migrates only Desktop and Documents and disables application migration.

Example:

```powershell
@{
    SchemaVersion = '1.0'

    Profile = @{
        Name        = 'Minimal'
        Description = 'Minimal user migration profile.'
    }

    Components = @(
        'Desktop'
        'Documents'
    )

    Applications = @{
        Enabled = $false
        Include = @()
    }

    Verification = @{
        Level = 'Standard'
    }
}
```

---

## Using a Migration Profile in Silent Mode

A built-in migration profile can be selected by name:

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File .\src\ProfMig.ps1 `
    -Silent `
    -SourceProfilePath 'C:\Users\SourceUser' `
    -DestinationProfilePath 'C:\Users\DestinationUser' `
    -MigrationProfile Standard
```

The `.psd1` extension is optional when a profile name is supplied.

For example:

```text
-MigrationProfile Standard
```

resolves to:

```text
src\Profiles\Standard.psd1
```

Similarly:

```text
-MigrationProfile Minimal
```

resolves to:

```text
src\Profiles\Minimal.psd1
```

An absolute path to a custom migration profile can also be supplied:

```powershell
-MigrationProfile 'C:\ProgramData\ProfMig\Profiles\Workstation.psd1'
```

---

## Profile Validation

Before a migration profile is used, ProfMig validates:

- Schema version
- Profile name
- Component selection
- Application settings
- Supported application identifiers
- Verification level

Invalid profiles produce structured ProfMig configuration errors.

Examples of invalid configuration include:

- Missing schema version
- Unsupported schema version
- Missing profile name
- Missing component configuration
- Unsupported migration component
- Invalid `Applications.Enabled` value
- Unsupported application identifier
- Unsupported verification level

A missing migration-profile file also produces a structured configuration error.

ProfMig does not silently replace an invalid requested profile with another profile.

---

## Configuration Merge Behaviour

Migration profiles are merged with the central ProfMig configuration.

For example, the Minimal profile changes:

```text
Folders
Application migration
Verification level, when configured
```

while retaining global settings such as:

```text
Retry
Storage validation
Hash algorithm
Excluded profiles
```

The global configuration supplied by the caller is not modified in place. ProfMig creates an effective migration configuration for the migration operation.

---

## Backward Compatibility

Sprint 5.3 extends the existing ProfMig configuration architecture.

It does not replace `Config.psd1`.

Existing ProfMig execution without `-MigrationProfile` continues to use the standard ProfMig configuration path and existing migration behavior.

Legacy global configurations without an explicit `SchemaVersion` remain supported.

Migration profiles are opt-in for silent-mode execution through `-MigrationProfile`.

This allows existing deployments and scripts to continue operating while standardized migrations can adopt reusable profiles.

---

## Security Considerations

Configuration files and migration profiles must not contain:

- Passwords
- Authentication tokens
- API keys
- Private keys
- Other credentials or secrets

Migration profiles cannot be used to disable existing ProfMig profile exclusions.

Configuration validation must complete successfully before migration proceeds.

Unknown schema versions, unsupported components, unsupported applications, and invalid safety settings are rejected rather than silently ignored.

---

## Example Deployment Scenarios

### Standard User Migration

Use:

```text
-MigrationProfile Standard
```

Suitable for a normal workstation migration where user folders and supported application data are migrated.

### Minimal User Migration

Use:

```text
-MigrationProfile Minimal
```

Suitable when only Desktop and Documents are required and application data must not be migrated.

### Managed Deployment

An administrator can maintain custom version-controlled `.psd1` migration profiles and deploy them together with ProfMig using an RMM platform, Microsoft Intune, or another software-deployment system.

This provides consistent migration selections without requiring interactive configuration on every endpoint.

---

## Related Components

Migration-profile configuration integrates with the existing ProfMig components:

- Configuration
- Command-Line and Silent Mode
- Pre-Migration Validation
- Copy Engine
- Application Migration
- Storage Validation
- Verification
- Logging
- Reporting
- Structured Error Handling

See also:

```text
docs\Command-Line-and-Silent-Mode.md
docs\Pre-Migration-Validation.md
docs\Migration-Verification-and-Data-Integrity.md
docs\Error-Handling-and-Recovery.md
```
