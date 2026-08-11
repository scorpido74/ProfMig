# ProfMig Inventory Engine

## Overview

The ProfMig Inventory Engine discovers Windows user profiles that can potentially be used as source or destination profiles during a profile migration.

The inventory functionality is implemented independently from the interactive menu. This allows the same inventory engine to be reused by future ProfMig components such as:

- Interactive menu
- GUI
- Command-line interface
- Silent execution mode
- Reporting
- Migration validation

The inventory engine is read-only and does not modify Windows profiles or profile registry information.

---

## Module

The Inventory Engine is implemented in:

```text
src\Modules\ProfMig.Inventory.psm1
```

The primary function is:

```powershell
Get-UserProfiles
```

---

## Profile discovery

ProfMig does not assume that every directory under:

```text
C:\Users
```

is a valid Windows profile.

Instead, registered Windows profiles are discovered through the Windows ProfileList registry:

```text
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList
```

The `ProfileImagePath` property is used to determine the actual profile location.

This is important because a Windows account name and its profile folder name are not always identical.

For example:

```text
Account : AzureAD\UserA
Profile : C:\Users\UserA
```

but Windows may also create profile directories such as:

```text
C:\Users\UserA.DOMAIN
C:\Users\UserA.001
C:\Users\TEMP.AzureAD
```

ProfMig therefore treats the registered profile path as the authoritative profile location.

---

## Inventory information

For every discovered profile, ProfMig returns a structured PowerShell object.

The following information is currently collected:

| Property | Description |
|---|---|
| `ProfileName` | Name derived from the registered profile directory |
| `ProfilePath` | Full Windows profile path |
| `SID` | SID associated with the ProfileList registry entry |
| `AccountName` | Resolved Windows account name where available |
| `AccountDomain` | Account domain, computer or identity provider where available |
| `Exists` | Indicates whether the profile path exists |
| `Accessible` | Indicates whether ProfMig can access the profile |
| `Status` | Basic profile status |
| `RelevantFolders` | Structured information about important profile folders |

Example:

```text
ProfileName   : UserA
ProfilePath   : C:\Users\UserA
SID           : S-1-5-21-...
AccountName   : UserA
AccountDomain : DOMAIN
Exists        : True
Accessible    : True
Status        : Available
```

---

## Account resolution

Where possible, ProfMig attempts to translate the profile SID into a Windows account.

This can result in account information such as:

```text
AzureAD\UserA
DOMAIN\UserA
COMPUTER\UserA
NT AUTHORITY\SYSTEM
```

SID translation is not guaranteed to succeed.

For example, translation can fail for:

- Deleted accounts
- Temporary profiles
- Disconnected accounts
- Old profile registry entries
- Invalid or renamed SID registry entries
- Accounts that are currently unavailable

Failure to resolve an account does not stop inventory processing.

The profile remains in the inventory with its available profile information.

---

## Profile exclusions

Profiles that should not normally be selected for migration are excluded using the ProfMig Configuration Engine.

Exclusions are configured centrally in:

```text
src\Config.psd1
```

Example:

```powershell
ExcludedProfiles = @(
    'All Users'
    'Default'
    'Default User'
    'Public'
    'defaultuser0'
    'WDAGUtilityAccount'
    'Administrator'
    'systemprofile'
    'LocalService'
    'NetworkService'
)
```

The Inventory Engine does not maintain a separate hardcoded list of excluded profile names.

The configured exclusions are supplied to the inventory function:

```powershell
Get-UserProfiles `
    -ExcludedProfiles $Config.ExcludedProfiles
```

This keeps profile exclusion policy centralized in the Configuration Engine.

---

## Profile status

Every returned profile receives a basic status.

### Available

```text
Status = Available
```

The registered profile path exists and ProfMig can access the profile.

### Inaccessible

```text
Status = Inaccessible
```

The profile exists, but ProfMig cannot successfully enumerate its contents.

This may occur because of:

- NTFS permissions
- Profile ownership
- Security restrictions
- Profile state
- Other Windows access restrictions

An inaccessible profile does not cause the entire inventory operation to fail.

### Missing

```text
Status = Missing
```

A registered profile entry exists, but its profile directory cannot be found or its existence cannot be reliably confirmed.

This can occur with old or orphaned ProfileList entries.

---

## Relevant user folders

ProfMig detects several directories that may be relevant during a future migration.

Currently these are:

```text
Desktop
Documents
Downloads
Pictures
Favorites
AppData
```

Each folder is represented by its own structured object containing:

```text
Path
Exists
Accessible
```

Example:

```text
Folder    Path                       Exists Accessible
------    ----                       ------ ----------
Desktop   C:\Users\UserA\Desktop       True       True
Documents C:\Users\UserA\Documents     True       True
Downloads C:\Users\UserA\Downloads     True       True
```

A folder not existing does not automatically mean that the entire Windows profile is invalid.

For example, folders can be redirected, removed, unavailable, or managed by another Windows or cloud-based mechanism.

---

## Structured output

The Inventory Engine returns PowerShell objects instead of formatted text.

Example:

```powershell
$Profiles = Get-UserProfiles `
    -ExcludedProfiles $Config.ExcludedProfiles
```

A profile can then be accessed programmatically:

```powershell
$Profiles[0].ProfileName
$Profiles[0].ProfilePath
$Profiles[0].SID
$Profiles[0].Status
```

Relevant folder information can be accessed using:

```powershell
$Profiles[0].RelevantFolders.Documents
```

This design allows the inventory results to be consumed without depending on `Write-Host` output.

---

## Menu integration

The ProfMig Menu module consumes the structured objects returned by the Inventory Engine.

The Menu is responsible for presenting profiles and allowing the operator to select one.

The Inventory Engine remains responsible only for discovering and describing profiles.

Conceptually:

```text
Configuration Engine
        |
        | ExcludedProfiles
        v
Inventory Engine
        |
        | Structured profile objects
        v
Menu / GUI / CLI / Silent Mode
```

A selected profile therefore remains a complete inventory object containing information such as:

```text
ProfileName
ProfilePath
SID
AccountName
AccountDomain
Exists
Accessible
Status
RelevantFolders
```

---

## Logging and diagnostics

The Inventory Engine supports PowerShell verbose output.

Example:

```powershell
Get-UserProfiles `
    -ExcludedProfiles $Config.ExcludedProfiles `
    -Verbose
```

Example diagnostic output:

```text
VERBOSE: Starting Windows profile inventory.
VERBOSE: Profile registry path: HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList
VERBOSE: Found 10 registered Windows profile entries.
VERBOSE: Profile discovered: UserA [Available]
VERBOSE: Excluded profile: systemprofile
VERBOSE: Profile discovered: UserB [Inaccessible]
VERBOSE: Profile inventory completed. 7 profile(s) returned.
```

Verbose logging does not change the returned inventory objects.

---

## Error handling

The Inventory Engine is designed to continue inventory processing where practical.

A problem with one profile should not normally prevent other profiles from being discovered.

Examples include:

- SID cannot be translated
- Profile is inaccessible
- Relevant folder is inaccessible
- Relevant folder does not exist
- Profile registry entry cannot be processed

Fatal conditions, such as the Windows ProfileList registry location being unavailable, result in an exception.

---

## Read-only behaviour

Inventory operations are read-only.

The Inventory Engine does not:

- Modify ProfileList
- Create profiles
- Delete profiles
- Rename profile directories
- Change profile permissions
- Change account information
- Copy user data
- Modify user files

Any future migration or modification functionality must remain outside the inventory discovery functions.

---

## Testing

Inventory Engine tests are located in:

```text
tests\ProfMig.Inventory.Tests.ps1
```

The tests validate:

- Inventory function availability
- Structured PowerShell output
- Required profile properties
- Relevant folder information
- Supported profile status values
- Configured profile exclusions
- Profile path availability
- SID information
- Predictable status information

Tests can be executed with:

```powershell
Invoke-Pester .\tests\ProfMig.Inventory.Tests.ps1
```

The Sprint 1.5 implementation was validated with Pester 3.4.0.

---

## Design principles

The ProfMig Inventory Engine follows these principles:

1. Do not assume every directory under `C:\Users` is a valid profile.
2. Use Windows profile registration information where practical.
3. Do not assume account names and profile folder names are identical.
4. Keep profile exclusions in the Configuration Engine.
5. Keep inventory operations read-only.
6. Return structured PowerShell objects.
7. Do not make core inventory functionality dependent on `Write-Host`.
8. Handle inaccessible or incomplete profiles predictably.
9. Keep inventory functionality reusable by future GUI, CLI and silent execution modes.

---

## Sprint 1.5 status

The Inventory Engine currently supports:

- Windows profile discovery
- ProfileList-based enumeration
- Profile path detection
- SID collection
- Account resolution where available
- Configurable profile exclusions
- Profile existence detection
- Profile accessibility detection
- Relevant folder detection
- Basic profile status
- Structured PowerShell output
- Menu consumption
- Verbose diagnostic logging
- Automated Pester testing

This provides the inventory foundation required by later ProfMig migration components.