# ProfMig Profile & Privilege Validation

## Overview

Sprint 3.2 adds profile and privilege validation to ProfMig's central
pre-migration validation framework.

The goal is to make sure ProfMig does not start copying profile data
when the source or destination profile is invalid, when the selected
profiles conflict, or when the current PowerShell process does not have
sufficient privileges.

Validation is non-destructive. ProfMig does not change permissions,
modify the source profile, or create temporary validation files inside
the destination profile.

## Objectives

Profile and privilege validation must determine whether:

-   the source profile exists and represents a valid Windows profile;
-   the destination profile path is valid;
-   source and destination are different;
-   profile paths are local and supported;
-   the source profile can be read;
-   the destination location can be written to;
-   the profile can be correlated with Windows profile registration and
    a SID where possible;
-   PowerShell is running with the required administrator privileges;
-   required Windows profile registry locations are accessible.

Critical failures are passed to the central validation engine and block
the migration before any data is copied.

## Architecture

Sprint 3.2 introduces:

`src/Modules/ProfMig.ProfileValidation.psm1`

This module contains Windows profile discovery, identity, structure,
privilege, and registry validation.

The existing:

`src/Modules/ProfMig.Validation.psm1`

remains the central validation engine and orchestration layer.

The validation flow is:

``` text
Invoke-ProfMigPreMigrationValidation
        |
        +-- Source profile validation
        |     +-- path
        |     +-- structure
        |     +-- registration
        |     +-- identity
        |     +-- read access
        |
        +-- Destination profile validation
        |     +-- path
        |     +-- existing profile structure
        |     +-- registration
        |     +-- identity
        |     +-- write permission
        |
        +-- Source/destination comparison
        |
        +-- Privilege validation
        |     +-- elevated administrator context
        |     +-- registry access
        |
        +-- Existing pre-migration checks
        |
        +-- Assert-ProfMigMigrationAllowed
```

`Assert-ProfMigMigrationAllowed` remains the blocking gate. If critical
validation failures are present, migration is stopped before the copy
phase.

## Windows profile discovery

ProfMig does not assume that a profile folder under `C:\Users` has the
same name as the Windows account.

Profile discovery uses Windows profile information, including
`Win32_UserProfile`, to correlate a local profile path with its SID.

Example:

``` text
C:\Users\BasvanEk
        |
        v
Win32_UserProfile
        |
        v
S-1-12-1-...
        |
        v
AzureAD\BasvanEk
        |
        v
AccountType = EntraID
```

This allows ProfMig to support profiles where the directory name and
account identity are not identical.

## Account identification

Where Windows can resolve the profile identity, ProfMig classifies
accounts as:

-   `Local`
-   `Domain`
-   `EntraID`
-   `MicrosoftAccount`
-   `Unknown`

Identity information can include:

-   profile path;
-   SID;
-   account name;
-   qualified account name;
-   account type;
-   identity source;
-   confidence;
-   Windows profile registration state;
-   registry profile path;
-   loaded state;
-   special-profile state.

Failure to classify an account type does not automatically make an
otherwise valid Windows profile unusable. Profile registration and SID
information remain more authoritative than the folder name.

## Source profile validation

The source profile is validated for:

-   existence;
-   valid local filesystem path;
-   expected Windows profile structure;
-   Windows profile registration;
-   profile identity where available;
-   read accessibility.

Expected profile structure uses Windows profile indicators such as
`NTUSER.DAT`, `AppData`, and Windows profile registration.

ProfMig does not require every standard user folder to exist because
folders such as Desktop, Documents, or Pictures can be redirected.

## Destination profile validation

The destination is validated before ProfMig creates or modifies
migration data.

Checks include:

-   valid local filesystem path;
-   existing Windows profile structure when the destination already
    exists;
-   Windows profile registration where applicable;
-   destination identity where available;
-   effective write-related access.

A destination does not have to exist before validation. If it does not
exist, ProfMig validates the appropriate existing parent location.

## Non-destructive write validation

Earlier validation logic used a temporary file to prove destination
write access.

Sprint 3.2 replaces this with a non-destructive NTFS ACL-based check.

Validation therefore does not:

-   create a temporary file;
-   delete a temporary file;
-   change an ACL;
-   grant permissions;
-   modify the destination profile.

This keeps validation compliant with the requirement that profile
validation must not alter source or destination profiles.

## Source and destination collision protection

ProfMig rejects source and destination combinations that resolve to the
same profile.

Paths are normalized before comparison so simple path formatting
differences cannot bypass the check.

A collision is a `Critical` validation failure and prevents migration.

## Local path validation

Profile paths are expected to be local filesystem paths.

UNC profile paths such as:

``` text
\\server\profiles\user
```

are rejected.

UNC validation is performed before filesystem access is attempted. This
prevents unreachable network paths from producing raw `Test-Path`
provider errors during validation.

An alternative local profile location outside `C:\Users`, such as
`D:\Profiles\User`, is not rejected solely because it is outside the
default Windows profile directory. Windows profile registration and
structure are used to determine whether it is a valid profile.

## Administrator validation

ProfMig determines whether the current PowerShell process is running
with an elevated administrator token.

When administrator privileges are required and unavailable, the result
is treated as a critical blocking failure.

The validation result also contains information about the current
Windows identity and SID.

## Registry validation

ProfMig validates access to Windows profile registry information,
including:

``` text
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList
```

When a profile SID is available, its corresponding ProfileList key can
also be validated.

For a loaded profile, the associated `HKEY_USERS\<SID>` hive can be
checked.

ProfMig does not load an unloaded user hive as part of validation.

If no SID is available, SID-specific registry validation returns a
warning rather than incorrectly reporting success.

## Structured validation results

Profile and privilege checks return structured results compatible with
the central pre-migration validation framework.

Typical properties include:

``` text
Check
Status
Severity
Message
Details
Timestamp
```

Status values include:

-   `Passed`
-   `Warning`
-   `Failed`

Severity is used by the central engine to determine whether a failure
must block migration.

The combined validation summary includes values such as:

``` text
CanProceed
HasWarnings
HasFailures
TotalChecks
PassedCount
WarningCount
FailedCount
CriticalFailures
Results
```

## Blocking behavior

Critical failures cause:

`CanProceed = False`

The central gate then blocks migration using:

``` powershell
Assert-ProfMigMigrationAllowed -ValidationSummary $validation
```

The resulting error includes the critical checks and their messages.

## Validation examples

### Valid Entra ID profile

Testing an Entra ID profile successfully resolved:

``` text
ProfilePath   : C:\Users\BasvanEk
QualifiedName : AzureAD\BasvanEk
AccountType   : EntraID
Registered    : True
Confidence    : High
```

The integrated validation completed with:

``` text
CanProceed       : True
HasWarnings      : False
HasFailures      : False
TotalChecks      : 18
PassedCount      : 18
WarningCount     : 0
FailedCount      : 0
CriticalFailures : 0
```

### Identical source and destination

Using the same profile for source and destination resulted in:

``` text
CanProceed       : False
HasFailures      : True
CriticalFailures : 1
```

The migration was therefore rejected.

### Non-existing source

A non-existing source produced critical failures for source existence,
profile structure, and source accessibility.

Example summary:

``` text
CanProceed       : False
HasFailures      : True
CriticalFailures : 3
```

### UNC source profile

A UNC source was rejected as unsupported.

Relevant critical checks included:

``` text
SourceProfile
SourceProfilePath
SourceProfileStructure
SourceAccessibility
```

Example summary:

``` text
CanProceed       : False
HasFailures      : True
CriticalFailures : 4
```

The validation returned structured results without attempting to use the
UNC profile as a supported local profile.

### Migration gate

Calling the migration gate with failed validation produces a terminating
error:

``` text
Pre-migration validation failed. Migration has been blocked.
```

This proves that validation failures are enforced and are not
informational only.

## Technical rules

Sprint 3.2 follows these rules:

-   do not rely only on `C:\Users\<username>`;
-   do not hardcode usernames;
-   do not change permissions during validation;
-   do not modify source profiles;
-   do not modify destination profiles for validation;
-   return structured validation results;
-   treat required privilege failures as critical;
-   use Windows profile registration and SID information where possible;
-   reject unsupported non-local profile paths before filesystem
    operations.

## Acceptance criteria status

The Sprint 3.2 implementation provides:

-   invalid source profile rejection;
-   invalid destination path validation;
-   source/destination collision protection;
-   insufficient privilege detection;
-   Windows profile discovery independent of folder naming;
-   Local, Domain, Entra ID, Microsoft Account, and Unknown identity
    classification where resolvable;
-   structured results integrated with the central validation engine;
-   non-destructive profile validation;
-   blocking behavior for critical failures.

## Definition of Done

Sprint 3.2 is complete when ProfMig can reliably validate source and
destination Windows profiles, correlate profile identity where possible,
determine whether the current process has sufficient privileges, and
prevent migration when critical validation checks fail.

The validation stage must complete before any migration data is copied
or profile data is modified.
