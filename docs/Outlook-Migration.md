# ProfMig Microsoft Outlook Migration

## Overview

ProfMig provides controlled migration support for Microsoft Outlook user data between Windows user profiles.

Outlook requires special handling because Outlook data contains a combination of:

- portable user data
- mailbox cache data
- profile-dependent configuration
- account-dependent configuration
- Microsoft 365 authentication data

ProfMig only migrates Outlook data that can safely be transferred to another Windows user profile.

Data that should be recreated by Outlook, Exchange, or Microsoft 365 is excluded.

---

## Supported Outlook versions

ProfMig detects both:

- Classic Outlook
- New Outlook for Windows

Where available, ProfMig records:

- Outlook type
- Classic Outlook installation path
- Classic Outlook version
- Classic Outlook architecture
- New Outlook installation
- New Outlook version
- New Outlook package information

A system can contain both Classic Outlook and New Outlook.

Example:

```text
OutlookType         : ClassicAndNew
ClassicDetected     : True
ClassicVersion      : 16.0.x
ClassicArchitecture : x64
NewOutlookDetected  : True
NewOutlookVersion   : 1.x

Migration policy

Outlook data is classified before migration.

ProfMig uses the following classifications:

Portable

Data that can safely be migrated to another Windows user profile.

Action:

Migrate
Recreate

Data that is dependent on the Outlook profile, mailbox, account, authentication context, or synchronized mailbox state.

Action:

Exclude

This data must be recreated by Outlook, Exchange, or Microsoft 365.

Supported migration data
Outlook signatures

Classic Outlook signatures are detected under:

%APPDATA%\Microsoft\Signatures

ProfMig migrates the complete signature file structure, including:

.htm
.rtf
.txt
supporting signature directories
supporting XML/theme files

Supporting directories are preserved because HTML signatures can reference files stored inside these directories.

Classification:

Portable

Action:

Migrate
Outlook templates

ProfMig detects Outlook email template data under:

%APPDATA%\Microsoft\Templates

Currently supported:

NormalEmail.dotm

NormalEmail.dotm contains Outlook email template/customization data and can be migrated between user profiles.

Other Microsoft Office templates are not automatically treated as Outlook migration data.

Classification:

Portable

Action:

Migrate
PST files

ProfMig detects PST files in the standard Outlook Files location:

%USERPROFILE%\Documents\Outlook Files

PST files contain portable Outlook user data and can be migrated.

ProfMig follows strict PST handling rules:

the source PST remains read-only
the PST is copied without modification
existing destination PST files are not overwritten
the copied file is validated after migration
source and destination file sizes must match

Classification:

Portable

Action:

Migrate
Outlook navigation settings

ProfMig supports migration of:

Outlook.xml

from:

%APPDATA%\Microsoft\Outlook

This file contains Classic Outlook navigation pane settings.

Classification:

Portable

Action:

Migrate
Outlook print settings

ProfMig supports migration of:

OutlPrnt

from:

%APPDATA%\Microsoft\Outlook

This file contains Classic Outlook print style configuration.

Classification:

Portable

Action:

Migrate
Excluded Outlook data
OST files

OST files are explicitly excluded from migration.

An OST normally contains synchronized mailbox data from Exchange or Microsoft 365.

The mailbox cache should be recreated by Outlook after the user configures or authenticates the destination Outlook profile.

ProfMig detects and reports OST files but does not copy them.

Classification:

Recreate

Action:

Exclude

This is a mandatory safety rule.

AutoComplete cache

Classic Outlook AutoComplete data can be stored in:

%LOCALAPPDATA%\Microsoft\Outlook\RoamCache

including files such as:

Stream_Autocomplete_*.dat

This data is profile-dependent and may also interact with mailbox/Microsoft 365 state.

ProfMig detects this data but does not automatically migrate it.

Classification:

Recreate

Action:

Exclude
Send/Receive settings

Classic Outlook can store Send/Receive configuration in:

Outlook.srs

under:

%APPDATA%\Microsoft\Outlook

These settings are dependent on the Outlook profile and configured accounts.

ProfMig therefore does not automatically migrate this file.

Classification:

Recreate

Action:

Exclude
Outlook profile configuration

Classic Outlook profile information can exist in the Windows registry under paths such as:

HKEY_USERS\<SID>\Software\Microsoft\Office\<version>\Outlook\Profiles

ProfMig detects Outlook profile information where available.

Outlook profile registry configuration is not copied to the destination Windows user.

The destination Outlook profile should be recreated normally.

This avoids transferring:

account-specific profile configuration
stale mailbox references
SID-dependent configuration
environment-specific configuration

Classification:

Recreate

Action:

Exclude
Microsoft 365 authentication

ProfMig does not migrate Microsoft 365 authentication.

This includes attempting to preserve:

authentication tokens
authenticated Microsoft 365 sessions
cached authentication state
account credentials

The destination user must authenticate normally after migration.

Policy:

AuthenticationPolicy : Reauthenticate

This exclusion is explicitly recorded in the ProfMig migration report.

New Outlook

ProfMig detects New Outlook for Windows where installed.

New Outlook is treated separately from Classic Outlook because its architecture and data storage model differ significantly from Classic Outlook.

ProfMig does not attempt to copy New Outlook authentication state, mailbox synchronization data, or application package state.

Microsoft 365 accounts and synchronized mailbox information should be recreated through normal New Outlook sign-in and synchronization.

Classic Outlook portable data is only migrated where ProfMig has an explicit supported migration rule.

Pre-flight validation

Before Outlook migration starts, ProfMig validates:

source profile exists
destination profile exists
source and destination profiles are different
Outlook is not running
Outlook data was detected
portable migration items are available
OST files are excluded
Microsoft 365 authentication is excluded

Migration is blocked when a required safety check fails.

Existing destination files

ProfMig follows a non-destructive migration policy.

Existing destination Outlook files are not overwritten.

When a destination file already exists:

Destination file already exists.

the item is skipped and recorded in the migration result.

This applies to supported Outlook portable data including signatures, templates, settings, and PST files.

Reporting

Outlook migration results integrate with the ProfMig reporting engine.

The report includes:

source profile
destination profile
migration start time
migration completion time
duration
files selected
files copied
files skipped
files excluded
files failed
bytes copied
skipped items
excluded items
failed items
warnings
errors
overall result

Outlook-specific exclusions are also reported.

Examples include:

Outlook.OST
Outlook.AutoComplete
Outlook.SendReceiveSettings
Outlook.Profile
Outlook.Authentication

Outlook.Authentication is reported as a security policy exclusion and is not counted as an excluded file.

Validated migration scenario

Sprint 2.4 was validated using a clean destination Windows user profile.

The tested source contained:

18 Signature items
1  Template
1  PST
1  OutlookSettings
1  PrintSettings

Total:

22 portable migration items

The clean migration successfully copied all 22 portable items.

Safety validation confirmed that the destination did not receive:

OST files       : False
RoamCache       : False
Outlook.srs     : False

The reporting engine successfully recorded the Outlook migration result and Outlook exclusions.

Limitations

ProfMig does not currently migrate:

OST mailbox caches
Microsoft 365 authentication tokens
authenticated Microsoft 365 sessions
Outlook account credentials
Outlook profile registry configuration
AutoComplete cache
Send/Receive configuration
New Outlook application state
New Outlook authentication state
synchronized mailbox data

Shared mailbox configuration is not explicitly migrated.

Shared mailboxes available through Microsoft 365 or Exchange should normally be restored through the recreated account/profile configuration.

Security principles

Outlook migration follows these rules:

Source Outlook data remains read-only.
PST files are never modified.
Existing destination files are not overwritten.
OST files are excluded by default.
Microsoft 365 authentication is never migrated.
Outlook profile configuration is recreated.
Profile-dependent data is excluded unless explicitly proven portable.
Migration operations are logged and reported.
Sprint 2.4 acceptance criteria
Requirement	Status
Detect Outlook-related data	Complete
Detect Outlook version/type	Complete
Detect PST files	Complete
Detect OST files	Complete
Exclude OST by default	Complete
Migrate signatures	Complete
Investigate/migrate supported templates	Complete
Investigate AutoComplete	Complete
Investigate Outlook profile settings	Complete
Investigate Classic Outlook	Complete
Investigate New Outlook	Complete
Prevent Microsoft 365 authentication migration	Complete
Preserve source PST	Complete
Integrate migration results with ProfMig reporting	Complete
Add logging	Complete
Document limitations	Complete
Definition of Done

Sprint 2.4 is complete when ProfMig can detect and migrate supported portable Outlook user data while safely excluding data that should be recreated or reauthenticated.

The Outlook migration engine satisfies this requirement.