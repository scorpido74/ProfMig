# ProfMig Generic AppData Migration Framework

## Overview

The Generic AppData Migration Framework provides a reusable method for migrating application data between Windows user profiles.

The framework prevents ProfMig from requiring application-specific copy logic for every supported application.

Applications can be defined using PowerShell data files (`.psd1`) containing:

- application metadata
- detection rules
- migration locations
- include rules
- exclusion rules
- validation rules

The generic framework handles:

1. application definition validation
2. application detection
3. path resolution
4. migration planning
5. include and exclusion processing
6. pre-migration validation
7. file migration through the ProfMig CopyEngine
8. post-migration validation
9. conversion to the ProfMig reporting format

Application definitions are stored in:

```text
src\Applications
```

The framework implementation is located in:

```text
src\Modules\ProfMig.AppMigration.psm1
```

---

## Design principles

The framework follows several important design principles.

### No application-specific copy engine

Applications define what should be migrated.

The generic framework determines how that definition is processed and uses the existing ProfMig CopyEngine to perform the actual file copy.

A new application should therefore not require a new copy engine.

### Never copy complete AppData blindly

The framework does not automatically copy complete:

```text
%APPDATA%
%LOCALAPPDATA%
```

directories.

Every migration location must define explicit include rules.

Files that do not match an include rule are not selected for migration.

### Exclusions take precedence

An exclusion rule always overrides an include rule.

For example:

```powershell
Include = @(
    '*.json'
)

Exclude = @(
    'credentials.json'
)
```

A file named:

```text
credentials.json
```

matches the include rule but is still excluded from migration.

This allows potentially security-sensitive application data to be explicitly blocked.

### Source data remains unchanged

The framework reads source application data and copies selected files to the destination profile.

Source files are not modified or removed.

### Existing destination files are not overwritten

The current framework uses the CopyEngine with:

```text
OverwritePolicy = Never
```

Existing destination files are skipped and reported as warnings.

---

# Architecture

The generic application migration flow is:

```text
Application Definition
        |
        v
Definition Validation
        |
        v
Application Detection
        |
        v
Migration Plan
        |
        v
Pre-Migration Validation
        |
        v
ProfMig CopyEngine
        |
        v
Post-Migration Validation
        |
        v
Application Migration Result
        |
        v
Reporting Adapter
        |
        v
ProfMig Reporting Engine
```

The application definition contains application-specific knowledge.

The core migration logic remains in:

```text
ProfMig.AppMigration.psm1
```

Actual file copying remains in:

```text
ProfMig.CopyEngine.psm1
```

Reporting remains in:

```text
ProfMig.Reporting.psm1
```

This separation prevents application definitions from containing migration engine logic.

---

# Configuration

The application definition directory is configured in:

```text
src\Config.psd1
```

Example:

```powershell
Paths = @{
    Logs                   = 'Logs'
    Reports                = 'Reports'
    Backup                 = 'Backup'
    ApplicationDefinitions = 'Applications'
}
```

During ProfMig startup the application definition directory is resolved relative to the `src` directory.

For example:

```text
C:\install\ProfMig\src\Applications
```

ProfMig loads and validates the definitions during startup.

Invalid definitions prevent the framework from silently continuing with an invalid application configuration.

---

# Application definition structure

An application is defined using a PowerShell data file.

Example:

```text
src\Applications\ProfMig.TestApp.psd1
```

The basic structure is:

```powershell
@{
    Application = @{
        Id          = 'Vendor.Application'
        Name        = 'Vendor Application'
        Description = 'Application description.'
    }

    Detect = @(
        @{
            Type = 'PathExists'
            Root = 'APPDATA'
            Path = 'Vendor\Application'
        }
    )

    Migration = @(
        @{
            Name = 'RoamingData'

            Source = @{
                Root = 'APPDATA'
                Path = 'Vendor\Application'
            }

            Destination = @{
                Root = 'APPDATA'
                Path = 'Vendor\Application'
            }

            Include = @(
                '*.json'
                '*.xml'
            )

            Exclude = @(
                'Cache\*'
                'Temp\*'
                'credentials.json'
            )
        }
    )

    Validation = @(
        @{
            Phase = 'PreMigration'
            Type  = 'PathExists'
            Root  = 'APPDATA'
            Path  = 'Vendor\Application'
        }

        @{
            Phase = 'PostMigration'
            Type  = 'PathExists'
            Root  = 'APPDATA'
            Path  = 'Vendor\Application'
        }
    )
}
```

---

# Application metadata

Every definition requires an `Application` section.

Required properties:

```powershell
Application = @{
    Id   = 'Vendor.Application'
    Name = 'Vendor Application'
}
```

## Id

`Id` is the unique technical identifier of the application.

Example:

```text
ProfMig.TestApp
```

The identifier is also used in migration and reporting component names.

Example:

```text
ProfMig.TestApp:RoamingData
ProfMig.TestApp:LocalData
```

## Name

`Name` is the human-readable application name.

Example:

```text
ProfMig Test Application
```

## Description

`Description` can be used to document the purpose of the definition.

---

# Supported application roots

The framework currently supports two application-data roots.

## APPDATA

`APPDATA` resolves to:

```text
<ProfilePath>\AppData\Roaming
```

Example:

```text
C:\Users\peter\AppData\Roaming
```

A definition containing:

```powershell
Root = 'APPDATA'
Path = 'Vendor\Application'
```

resolves to:

```text
C:\Users\peter\AppData\Roaming\Vendor\Application
```

## LOCALAPPDATA

`LOCALAPPDATA` resolves to:

```text
<ProfilePath>\AppData\Local
```

Example:

```text
C:\Users\peter\AppData\Local
```

A definition containing:

```powershell
Root = 'LOCALAPPDATA'
Path = 'Vendor\Application'
```

resolves to:

```text
C:\Users\peter\AppData\Local\Vendor\Application
```

No usernames are stored in application definitions.

The selected Windows profile determines the actual profile path.

---

# Path security

Application paths must always be relative paths.

The framework rejects absolute paths such as:

```text
C:\Windows
```

The framework also rejects path traversal such as:

```text
..\..\Windows
```

This prevents an application definition from escaping its configured APPDATA or LOCALAPPDATA root.

Valid example:

```text
Vendor\Application\Config
```

Invalid examples:

```text
C:\Windows
..\Windows
Vendor\..\..\Windows
```

---

# Detection rules

The `Detect` section determines whether application data exists in a source profile.

Currently supported detection type:

```text
PathExists
```

Example:

```powershell
Detect = @(
    @{
        Type = 'PathExists'
        Root = 'APPDATA'
        Path = 'Vendor\Application'
    }
)
```

All configured detection rules must match for the application to be considered detected.

Possible detection status values include:

```text
Detected
NotDetected
```

Detection itself does not copy any data.

---

# Migration locations

An application can contain multiple migration locations.

For example:

```powershell
Migration = @(
    @{
        Name = 'RoamingData'

        Source = @{
            Root = 'APPDATA'
            Path = 'Vendor\Application'
        }

        Destination = @{
            Root = 'APPDATA'
            Path = 'Vendor\Application'
        }

        Include = @(
            '*.json'
        )

        Exclude = @(
            'credentials.json'
        )
    }

    @{
        Name = 'LocalData'

        Source = @{
            Root = 'LOCALAPPDATA'
            Path = 'Vendor\Application'
        }

        Destination = @{
            Root = 'LOCALAPPDATA'
            Path = 'Vendor\Application'
        }

        Include = @(
            'Settings\*'
        )

        Exclude = @(
            'Cache\*'
        )
    }
)
```

This produces logical migration components such as:

```text
Vendor.Application:RoamingData
Vendor.Application:LocalData
```

---

# Include rules

Include rules determine which files are eligible for migration.

Example:

```powershell
Include = @(
    '*.json'
    '*.xml'
    'Config\*'
)
```

A file must match at least one include rule before it can be selected.

Files that match no include rule receive:

```text
NotIncluded
```

They are not copied.

Examples:

```text
settings.json       Included
preferences.xml     Included
Cache\cache.db      NotIncluded
```

---

# Exclusion rules

Exclusion rules prevent files from being migrated even when they match an include rule.

Example:

```powershell
Exclude = @(
    '*.lock'
    'Cache\*'
    'Temp\*'
    'credentials.json'
)
```

Example result:

```text
credentials.json
```

may match:

```text
*.json
```

but is still classified as:

```text
Excluded
```

because:

```text
credentials.json
```

matches an exclusion rule.

This behavior is particularly important for security-sensitive data.

---

# Migration plan

Before copying data, the framework creates a migration plan.

The plan contains information including:

```text
ApplicationId
ApplicationName
SourceProfile
DestinationProfile
Detected
Status
FilesDetected
FilesIncluded
FilesExcluded
FilesNotIncluded
BytesSelected
Items
```

Possible plan status values include:

```text
Ready
NotDetected
NothingToMigrate
```

Each detected file receives information such as:

```text
Location
RelativePath
SourceFile
DestinationFile
Status
IncludeRule
ExcludeRule
Reason
```

Typical item statuses are:

```text
Included
Excluded
NotIncluded
```

---

# Validation

The framework supports validation rules before and after migration.

Supported phases:

```text
PreMigration
PostMigration
```

Currently supported validation type:

```text
PathExists
```

Example:

```powershell
Validation = @(
    @{
        Phase = 'PreMigration'
        Type  = 'PathExists'
        Root  = 'APPDATA'
        Path  = 'Vendor\Application'
    }

    @{
        Phase = 'PostMigration'
        Type  = 'PathExists'
        Root  = 'APPDATA'
        Path  = 'Vendor\Application'
    }
)
```

## Pre-migration validation

Pre-migration validation runs against the source profile.

If required validation fails, migration is blocked before the CopyEngine starts.

Example:

```text
Status        : Blocked
FilesSelected : 0
FilesCopied   : 0
PreValidation : Failed
```

This ensures invalid source conditions do not result in a partial migration.

## Post-migration validation

Post-migration validation runs against the destination profile after copying.

A failed post-migration validation changes the migration result to an error state.

---

# CopyEngine integration

The generic framework does not implement its own file-copy engine.

Selected files are passed to:

```text
Invoke-ProfMigFileCopy
```

from:

```text
ProfMig.CopyEngine.psm1
```

Each selected file is copied individually using the existing ProfMig CopyEngine behavior.

The current overwrite policy is:

```text
Never
```

If the destination file already exists, it is skipped.

Example migration status:

```text
CompletedWithWarnings
```

---

# Migration result

`Invoke-ProfMigApplicationMigration` returns a structured result containing information such as:

```text
ApplicationId
ApplicationName
SourceProfile
DestinationProfile
StartedAt
CompletedAt
Duration
Status
Plan
PreValidation
PostValidation
FilesSelected
FilesCopied
FilesSkipped
FilesExcluded
FilesFailed
BytesCopied
Components
SkippedItems
ExcludedItems
Errors
```

Possible migration statuses include:

```text
Success
CompletedWithWarnings
CompletedWithErrors
Blocked
NotDetected
NothingToMigrate
```

---

# Reporting integration

Application migration results are converted to the existing ProfMig reporting contract using:

```text
ConvertTo-ProfMigApplicationCopyResult
```

The reporting adapter groups individual CopyEngine file operations into logical application components.

For example, four copied files from one roaming location are reported as:

```text
ProfMig.TestApp:RoamingData
```

rather than four separate components.

Example:

```text
Component                    Selected  Copied  Skipped  Excluded  Failed
ProfMig.TestApp:RoamingData         4       0        4         1       0
ProfMig.TestApp:LocalData           1       0        1         0       0
```

Excluded application-plan items are also converted to the existing ProfMig reporting format.

Blocked migrations can therefore also be processed by the standard reporting engine.

---

# Adding a new application

Adding a new application should normally require only a new application definition.

## Step 1 - Identify application data

Determine which application data is stored under:

```text
%APPDATA%
%LOCALAPPDATA%
```

Do not assume that the complete application directory is safe or useful to migrate.

Identify:

- configuration files
- user preferences
- templates
- application state
- caches
- temporary files
- logs
- credentials
- tokens
- machine-specific data

Only data known to be portable should be included.

## Step 2 - Create the definition

Create:

```text
src\Applications\<ApplicationId>.psd1
```

For example:

```text
src\Applications\Vendor.Application.psd1
```

## Step 3 - Define application metadata

Example:

```powershell
Application = @{
    Id          = 'Vendor.Application'
    Name        = 'Vendor Application'
    Description = 'Migrates portable Vendor Application settings.'
}
```

## Step 4 - Add detection

Example:

```powershell
Detect = @(
    @{
        Type = 'PathExists'
        Root = 'APPDATA'
        Path = 'Vendor\Application'
    }
)
```

## Step 5 - Define migration locations

Add only the locations required by the application.

Example:

```powershell
Migration = @(
    @{
        Name = 'RoamingData'

        Source = @{
            Root = 'APPDATA'
            Path = 'Vendor\Application'
        }

        Destination = @{
            Root = 'APPDATA'
            Path = 'Vendor\Application'
        }

        Include = @(
            '*.json'
            '*.xml'
        )

        Exclude = @(
            'Cache\*'
            'Temp\*'
            '*.lock'
            'credentials.json'
        )
    }
)
```

## Step 6 - Add validation

Example:

```powershell
Validation = @(
    @{
        Phase = 'PreMigration'
        Type  = 'PathExists'
        Root  = 'APPDATA'
        Path  = 'Vendor\Application'
    }

    @{
        Phase = 'PostMigration'
        Type  = 'PathExists'
        Root  = 'APPDATA'
        Path  = 'Vendor\Application'
    }
)
```

## Step 7 - Validate the definition

Run:

```powershell
Import-Module .\src\Modules\ProfMig.AppMigration.psm1 -Force

$app = Import-PowerShellDataFile `
    .\src\Applications\Vendor.Application.psd1

Test-ProfMigApplicationDefinition `
    -Definition $app
```

Expected:

```text
Valid : True
Errors: {}
```

## Step 8 - Test detection

```powershell
Test-ProfMigApplicationDetection `
    -Definition $app `
    -ProfilePath 'C:\Users\<sourceprofile>'
```

Confirm that detection behaves correctly for profiles both with and without the application.

## Step 9 - Inspect the migration plan

```powershell
$plan = Get-ProfMigApplicationMigrationPlan `
    -Definition $app `
    -SourceProfile 'C:\Users\<sourceprofile>' `
    -DestinationProfile 'C:\Users\<destinationprofile>'

$plan.Items |
    Select-Object `
        Location,
        RelativePath,
        Status,
        IncludeRule,
        ExcludeRule,
        Reason |
    Format-Table -AutoSize
```

Review every selected and excluded file before using the definition in production.

Pay particular attention to:

```text
credentials
tokens
cookies
sessions
keys
databases
machine-specific state
cache data
```

## Step 10 - Test validation

```powershell
Test-ProfMigApplicationValidation `
    -Definition $app `
    -ProfilePath 'C:\Users\<sourceprofile>' `
    -Phase PreMigration
```

Confirm that invalid source conditions correctly fail validation.

## Step 11 - Test migration

```powershell
$result = Invoke-ProfMigApplicationMigration `
    -Definition $app `
    -SourceProfile 'C:\Users\<sourceprofile>' `
    -DestinationProfile 'C:\Users\<destinationprofile>'
```

Review:

```powershell
$result |
    Select-Object `
        Status,
        FilesSelected,
        FilesCopied,
        FilesSkipped,
        FilesExcluded,
        FilesFailed,
        BytesCopied
```

## Step 12 - Test reporting

```powershell
$copyResult = ConvertTo-ProfMigApplicationCopyResult `
    -ApplicationResult $result

$reportResult = ConvertTo-ProfMigMigrationResult `
    -CopyResult $copyResult `
    -ProfMigVersion '1.0'

New-ProfMigMigrationReport `
    -MigrationResult $reportResult `
    -ReportFolder .\Reports
```

The report should contain logical application components and any skipped, excluded or failed items.

---

# Definition checklist

Before adding an application definition, verify:

- the application has a unique `Application.Id`
- no usernames are hardcoded
- only `APPDATA` or `LOCALAPPDATA` roots are used
- all configured paths are relative
- complete AppData directories are not blindly included
- include rules select only required portable data
- caches and temporary files are excluded where appropriate
- credentials and other sensitive data are reviewed explicitly
- pre-migration validation is appropriate
- post-migration validation is appropriate
- migration does not overwrite existing destination data
- the source profile remains unchanged
- the migration plan has been manually reviewed
- reporting works for success, warning and blocked scenarios

---

# Current application modules

Microsoft Edge, Google Chrome and Microsoft Outlook currently have dedicated ProfMig migration modules.

These modules are not automatically replaced by the generic framework in Sprint 2.5.

They can eventually be refactored to use parts of the generic framework where their migration requirements fit the definition model.

Applications with more complex behavior may still require application-specific detection, transformation or validation logic.

The goal of the generic framework is to eliminate unnecessary application-specific copy logic, not to force every application into an unsuitable definition.

---

# Test application

Sprint 2.5 includes:

```text
src\Applications\ProfMig.TestApp.psd1
```

This definition is intended to validate framework functionality including:

- APPDATA support
- LOCALAPPDATA support
- detection
- include rules
- exclusion rules
- security-sensitive exclusions
- migration planning
- pre-migration validation
- post-migration validation
- CopyEngine integration
- reporting integration

It should not be treated as a production application definition.

---

# Security considerations

Application data can contain sensitive information.

Examples include:

```text
credentials
authentication tokens
cookies
browser sessions
encryption keys
cached secrets
account databases
```

An application directory being present under APPDATA or LOCALAPPDATA does not mean all its contents are portable.

Application definitions should follow an allow-list approach:

```text
Explicitly include known portable data.
Explicitly exclude known sensitive or machine-specific data.
Do not copy everything by default.
```

When the portability or security impact of a file is unknown, it should not be included until its behavior has been verified.

