# Application Exclusion Engine

## Overview

Sprint 2.6 introduces a central application exclusion engine for ProfMig.

The exclusion engine prevents unsafe, unnecessary or non-portable application data from being migrated between Windows user profiles.

Exclusion rules are maintained centrally in:

`src\Modules\ProfMig.Exclusions.psm1`

The copy engine and supported application migration modules consume these rules instead of implementing security-sensitive exclusions independently.

## Objectives

The exclusion engine is designed to:

- Prevent security-sensitive data from being copied
- Prevent non-portable application data from being migrated
- Keep source data untouched
- Make exclusions auditable through logging and reporting
- Allow new exclusions to be added without modifying the core copy logic
- Provide application-specific exclusions where required
- Ensure security exclusions take precedence over generic or application rules

## Supported Rule Types

The engine supports the following rule types:

### RelativePath

Matches a relative path using PowerShell wildcard matching.

Example:

`AppData\Roaming\Microsoft\Credentials\*`

### FileName

Matches a specific file name.

FileName rules also protect associated SQLite sidecar files:

- `-journal`
- `-wal`
- `-shm`

For example, a rule for:

`Login Data`

also excludes:

- `Login Data-journal`
- `Login Data-wal`
- `Login Data-shm`

### DirectoryName

Matches a directory anywhere in the relative path.

The engine also supports explicit directory objects through the `IsDirectory` parameter.

### Extension

Matches a file extension.

Example:

`.ost`

## Rule Structure

A rule contains the following properties:

- RuleId
- RuleType
- Pattern
- Category
- Application
- Reason
- Mandatory

Example:

```powershell
@{
    RuleId    = 'SEC-006'
    RuleType  = 'Extension'
    Pattern   = '.ost'
    Category  = 'Security'
    Reason    = 'OST files should be rebuilt by Outlook'
    Mandatory = $true
}