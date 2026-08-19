# ProfMig Pre-Migration Validation

## Overview

ProfMig uses a central pre-migration validation engine to determine whether a profile migration can safely start.

Before the Copy Engine is allowed to copy migration data, ProfMig validates the source profile, destination profile, permissions, configuration, available storage and other critical migration conditions.

The validation framework was introduced in **Sprint 3.1 - Pre-Migration Validation**.

The central validation module is:

```text
src/Modules/ProfMig.Validation.psm1
```

The validation engine is designed to be reusable by the ProfMig CLI, menu system, reporting engine and a future GUI.

---

## Objectives

The pre-migration validation framework ensures that:

* The source profile exists.
* The destination profile exists or is valid for migration.
* Source and destination profiles are different.
* Required source directories are accessible.
* The destination is writable.
* ProfMig has sufficient privileges.
* Required configuration is valid.
* Sufficient destination disk space is available.
* No known critical condition prevents the migration.
* Critical failures block the migration before copying starts.
* Warnings can be distinguished from critical failures.
* Validation results are returned as structured PowerShell objects.
* Validation results can be logged and included in reporting.

Validation must never modify source profile data.

---

## Architecture

The central entry point for validation is:

```powershell
Invoke-ProfMigPreMigrationValidation
```

The migration flow is:

```text
Migration Request
       |
       v
Pre-Migration Validation
       |
       v
Validation Summary
       |
       +---- Critical failure ----> Migration blocked
       |
       +---- No critical failure -> Copy Engine
```

The Copy Engine must not duplicate validation logic.

`ProfMig.CopyEngine.psm1` calls the central validation engine before starting any copy operation.

The migration gate is enforced using:

```powershell
Assert-ProfMigMigrationAllowed
```

---

## Validation Result Object

Every validation check returns a structured PowerShell object.

Example:

```powershell
[PSCustomObject]@{
    PSTypeName = 'ProfMig.ValidationResult'
    Check      = 'SourceProfile'
    Status     = 'Passed'
    Severity   = 'Critical'
    Message    = 'Source profile exists.'
    Details    = $Details
    Timestamp  = Get-Date
}
```

This allows validation results to be consumed without depending on console output or `Write-Host`.

---

## Validation Status

ProfMig supports the following validation statuses.

### Passed

The validation check completed successfully.

Example:

```text
Check:     SourceProfile
Status:    Passed
Severity:  Critical
Message:   Source profile exists.
```

### Warning

A condition was detected that should be presented to the administrator, but does not necessarily prevent migration.

Example:

```text
Check:     FreeDiskSpace
Status:    Warning
Severity:  Warning
Message:   Destination has sufficient capacity, but remaining disk space is low.
```

Warnings do not automatically block migration.

The menu or future GUI may require administrator confirmation before continuing.

### Failed

The validation check failed.

A failed check with severity `Critical` prevents migration.

Example:

```text
Check:     DestinationWritable
Status:    Failed
Severity:  Critical
Message:   Destination is not writable.
```

---

## Severity Levels

ProfMig supports the following severity levels:

```text
Information
Warning
Critical
```

### Information

Provides informational validation results that do not prevent migration.

### Warning

Indicates a condition that requires administrator attention but may allow migration to continue.

### Critical

Indicates a condition that can make the migration unsafe or impossible.

A result with:

```text
Status   = Failed
Severity = Critical
```

blocks the migration.

---

## Validation Checks

### SourceProfile

Function:

```powershell
Test-ProfMigSourceProfile
```

Verifies that the configured source profile exists and is a directory.

Failure severity:

```text
Critical
```

A missing source profile blocks migration.

---

### DestinationProfile

Function:

```powershell
Test-ProfMigDestinationProfile
```

Verifies that the destination profile exists or that its location is valid for migration.

If the destination profile does not yet exist, its parent location must be valid and accessible.

The validation check itself does not create the destination profile.

Failure severity:

```text
Critical
```

---

### ProfilesDiffer

Function:

```powershell
Test-ProfMigProfilesDiffer
```

Verifies that the source and destination profiles are not the same directory.

Paths are normalized before comparison.

Example of an invalid migration:

```text
Source:      C:\Users\User1
Destination: C:\Users\User1
```

Failure severity:

```text
Critical
```

This prevents ProfMig from copying a profile onto itself.

---

### SourceAccessibility

Function:

```powershell
Test-ProfMigSourceAccessibility
```

Verifies access to required source profile directories.

Default directories include:

```text
Desktop
Documents
Downloads
Favorites
AppData
```

Only directories that exist are tested.

The validation performs read operations only and does not modify source data.

Failure severity:

```text
Critical
```

---

### DestinationWritable

Function:

```powershell
Test-ProfMigDestinationWritable
```

Verifies that ProfMig can write to the destination.

The validation engine creates a uniquely named temporary validation file and immediately removes it.

Example:

```text
.profmig-validation-<GUID>.tmp
```

If the destination profile does not yet exist, write access can be tested against the parent destination directory.

No source data is modified.

Failure severity:

```text
Critical
```

---

### Privileges

Function:

```powershell
Test-ProfMigPrivileges
```

Verifies that ProfMig is running with sufficient Windows privileges.

By default, ProfMig requires administrative privileges for profile migration.

Example successful result:

```text
Status:   Passed
Severity: Critical
Message:  ProfMig is running with administrative privileges.
```

Insufficient privileges result in a critical failure.

---

### Configuration

Function:

```powershell
Test-ProfMigConfiguration
```

Validates required ProfMig configuration properties.

The Copy Engine currently requires:

```text
Folders
```

The Copy Engine invokes validation using:

```powershell
-RequiredConfigurationProperties @('Folders')
```

Missing or invalid required configuration results in a critical validation failure.

Configuration validation is centralized to prevent duplicate validation logic across ProfMig modules.

---

### FreeDiskSpace

Function:

```powershell
Test-ProfMigDiskSpace
```

Determines whether the destination has sufficient free disk capacity for the migration.

The validation engine calculates the source migration size and applies a configurable safety buffer.

Default safety buffer:

```text
10%
```

Conceptually:

```text
RequiredCapacity = SourceSize + SafetyBuffer
```

Example:

```text
Source data:       20 GB
Safety buffer:      2 GB
Required capacity: 22 GB
Available space:   80 GB

Result: Passed
```

If available capacity is below the required capacity:

```text
Status:   Failed
Severity: Critical
```

The migration is blocked.

If sufficient capacity exists but remaining free disk space is close to the configured threshold:

```text
Status:   Warning
Severity: Warning
```

The migration may continue.

---

### CriticalConditions

Function:

```powershell
Test-ProfMigCriticalConditions
```

Provides a central location for additional ProfMig-wide safety checks.

Current checks include protection against unsafe profile path relationships.

For example:

```text
Destination located inside source profile
```

or:

```text
Source located inside destination profile
```

These conditions are blocked because they could result in recursive or unsafe copy behavior.

Known Windows system locations are also protected from accidentally being selected as migration profile roots.

Critical conditions result in:

```text
Status:   Failed
Severity: Critical
```

---

## Validation Summary

After all validation checks complete, ProfMig creates a summary object.

Example:

```powershell
[PSCustomObject]@{
    PSTypeName       = 'ProfMig.ValidationSummary'
    CanProceed       = $true
    HasWarnings      = $false
    HasFailures      = $false
    TotalChecks      = 9
    PassedCount      = 9
    WarningCount     = 0
    FailedCount      = 0
    CriticalFailures = 0
    Results          = $Results
    Timestamp        = Get-Date
}
```

The most important property is:

```powershell
CanProceed
```

If:

```powershell
$validation.CanProceed -eq $true
```

the migration may continue.

If:

```powershell
$validation.CanProceed -eq $false
```

the migration must not start.

---

## Migration Blocking Gate

The Copy Engine performs validation before starting migration.

Conceptually:

```powershell
$validation = Invoke-ProfMigPreMigrationValidation `
    -SourceProfile $SourceProfile `
    -DestinationProfile $DestinationProfile `
    -Configuration $Configuration `
    -RequiredConfigurationProperties @('Folders')

Assert-ProfMigMigrationAllowed `
    -ValidationSummary $validation
```

`Assert-ProfMigMigrationAllowed` checks the validation summary.

If one or more critical failures exist, it throws an exception and prevents the Copy Engine from starting.

Example:

```text
Pre-migration validation failed. Migration has been blocked.
```

This creates a hard safety boundary between validation and migration execution.

---

## Copy Engine Integration

`ProfMig.CopyEngine.psm1` imports:

```text
ProfMig.Validation.psm1
```

before migration functions are executed.

The intended execution order is:

```text
Load ProfMig modules
        |
        v
Initialize exclusion rules
        |
        v
Invoke-ProfMigCopy
        |
        v
Invoke-ProfMigPreMigrationValidation
        |
        v
Assert-ProfMigMigrationAllowed
        |
        +---- Failed ---> STOP
        |
        v
Copy migration components
```

The validation summary is retained so it can be consumed by migration reporting.

---

## Logging

Validation results can be passed to the ProfMig logging framework.

Function:

```powershell
Write-ProfMigValidationLog
```

Validation statuses are mapped to logging levels:

```text
Passed  -> Information
Warning -> Warning
Failed  -> Error
```

Logging failures must not replace or hide validation results.

The structured validation result remains the authoritative result of each validation check.

---

## Reporting

Function:

```powershell
ConvertTo-ProfMigValidationReport
```

converts the validation summary into a reporting-friendly structure.

The reporting engine can consume:

```text
CanProceed
HasWarnings
TotalChecks
PassedCount
WarningCount
FailedCount
CriticalFailures
Results
Timestamp
```

Each individual result contains:

```text
Check
Status
Severity
Message
Details
Timestamp
```

This makes validation reporting independent from console output.

---

## Example

Run validation manually:

```powershell
$validation = Invoke-ProfMigPreMigrationValidation `
    -SourceProfile 'C:\ProfMigTest\Source' `
    -DestinationProfile 'C:\ProfMigTest\Destination' `
    -Configuration @{
        Folders = @(
            'Desktop'
            'Documents'
            'Downloads'
        )
    } `
    -RequiredConfigurationProperties @('Folders')
```

Display validation results:

```powershell
$validation.Results |
    Format-Table Check, Status, Severity, Message -AutoSize
```

Example successful result:

```text
Check                 Status  Severity
-----                 ------  --------
SourceProfile         Passed  Critical
DestinationProfile    Passed  Critical
ProfilesDiffer        Passed  Critical
SourceAccessibility   Passed  Critical
DestinationWritable   Passed  Critical
Privileges            Passed  Critical
Configuration         Passed  Critical
FreeDiskSpace         Passed  Critical
CriticalConditions    Passed  Critical
```

Verify whether migration is allowed:

```powershell
$validation.CanProceed
```

Expected result:

```text
True
```

---

## Safety Principles

The ProfMig pre-migration validation framework follows these principles:

1. Validation must complete before migration data is copied.
2. Source data must never be modified during validation.
3. Critical failures must block migration.
4. Warnings must remain distinguishable from failures.
5. Validation logic must be centralized.
6. Core validation functions must not depend on `Write-Host`.
7. Results must be returned as structured PowerShell objects.
8. Validation must be reusable by CLI, menu, GUI and reporting components.
9. Logging must not determine validation outcome.
10. Copy Engine modules must not duplicate central validation logic.

---

## Sprint 3.1 Acceptance Criteria

Sprint 3.1 is considered complete when:

* ProfMig performs pre-migration validation before copying data.
* Source profile validation is implemented.
* Destination profile validation is implemented.
* Source and destination profile equality is prevented.
* Source accessibility is validated.
* Destination write access is validated.
* Privilege validation is integrated.
* Configuration validation is integrated.
* Storage validation is integrated.
* Known critical migration conditions are checked.
* Critical failures prevent migration.
* Warnings can be distinguished from failures.
* Validation results are structured PowerShell objects.
* Validation results can be logged.
* Validation results can be consumed by reporting.
* Validation logic is reusable by the menu and a future GUI.
* Validation checks are documented.

---

## Definition of Done

Sprint 3.1 is complete when ProfMig has a central pre-migration validation framework that determines whether a migration is safe to start and prevents the Copy Engine from running when a critical validation failure is detected.
