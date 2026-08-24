The destination account could use:

Destination user SID
S-1-12-1-123456789-987654321-111111111-222222222

Copying the source ACL directly could leave the migrated object accessible only to the old source SID.

This can cause:

Access denied errors
Inaccessible migrated files
Incorrect ownership
Orphaned SID entries
Broken inheritance
Unexpected application behaviour

ProfMig therefore evaluates destination permissions independently from the source ACL.

ACL Strategy

ProfMig uses the following strategy.

1. Determine Destination SID

The destination Windows profile is resolved to its registered SID.

ProfMig does not assume that the profile folder name equals the Windows username.

Example:

ProfilePath : C:\Users\User
Sid         : S-1-12-1-...
Registered  : True
Success     : True

The SID is obtained from Windows profile registration information.

2. Inspect Destination ACL

After data has been copied, ProfMig evaluates the ACL of the destination object.

The following properties are inspected:

Destination user access
Source SID presence
NTFS inheritance
SYSTEM access
Administrators access
ACL readability

Example validation result:

Valid                 : True
DestinationUserAccess : True
SourceSidPresent      : False
InheritanceEnabled    : True
SystemAccessPresent   : True
AdministratorsPresent : True
RemediationRequired   : False
3. Prefer Destination Inheritance

Normal destination profile inheritance is the preferred permission model.

For example:

C:\Users\DestinationUser
    |
    +-- Documents
         |
         +-- MigratedFile.txt

Where possible, MigratedFile.txt inherits its permissions from the destination Documents directory.

This avoids creating unnecessary custom ACLs.

Typical inherited permissions include:

NT AUTHORITY\SYSTEM       FullControl
BUILTIN\Administrators    FullControl
Destination User          FullControl

The exact effective rights remain determined by normal Windows ACL behaviour.

4. Validate Parent ACL

Before restoring inheritance, ProfMig checks whether the parent directory provides suitable access for the destination user.

Test-ProfMigParentAcl validates the parent ACL before ProfMig relies on inheritance.

Example:

ParentFound           : True
DestinationUserAccess : True
InheritanceSuitable   : True
Success               : True

Inheritance is therefore not enabled blindly.

5. Repair Broken Inheritance

If an object:

Does not provide destination-user access
Has inheritance disabled
Has a suitable destination parent ACL

ProfMig can restore inheritance.

Example action:

EnableInheritance

The ACL is validated again immediately after the change.

If destination access is restored through inheritance, no explicit destination ACE is required.

6. Explicit Destination Access

If inheritance cannot safely provide destination-user access, ProfMig can add an explicit destination-user permission.

The fallback permission is:

Destination SID
Modify
Allow

ProfMig does not grant Everyone access and does not grant Full Control as a generic fallback.

Explicit permissions are only used when required.

Source SID Handling

ProfMig can detect whether the source SID is present in an ACL.

Finding:

ACL-SOURCE-SID-PRESENT

The presence of the source SID does not automatically mean that remediation is required.

For example:

SourceSidPresent    : True
RemediationRequired : False

If the destination user already has valid access and the ACL is otherwise secure, ProfMig avoids unnecessary ACL modifications.

This prevents aggressive ACL rewriting.

ACL Findings

Sprint 3.5 defines ACL findings including:

ACL-DESTINATION-NO-ACCESS

The destination SID does not have sufficient access to the object.

This normally requires remediation.

ACL-INHERITANCE-DISABLED

NTFS inheritance is disabled.

ProfMig evaluates whether inheritance can safely be restored from the parent directory.

ACL-SOURCE-SID-PRESENT

The source SID exists in the ACL.

This is informational unless it contributes to an actual access problem.

ACL-SYSTEM-MISSING

The expected SYSTEM access is not present.

This is reported because SYSTEM access can be required by Windows and applications.

ACL-ADMINISTRATORS-MISSING

The expected Administrators access is not present.

This is reported because administrative access should not accidentally be removed during migration.

Permission Module

Sprint 3.5 introduces:

src/Modules/ProfMig.Permissions.psm1

Public functions:

Get-ProfMigAclInfo
Get-ProfMigProfileSid
Get-ProfMigUserSid
Repair-ProfMigDestinationPermissions
Test-ProfMigAcl
Test-ProfMigParentAcl
Get-ProfMigProfileSid

Resolves the Windows SID associated with a registered profile path.

Example:

Get-ProfMigProfileSid `
    -ProfilePath 'C:\Users\DestinationUser'

Example result:

ProfilePath : C:\Users\DestinationUser
Sid         : S-1-12-1-...
Registered  : True
Success     : True
Error       :
Get-ProfMigAclInfo

Returns normalized ACL information for a file or directory.

Example:

Get-ProfMigAclInfo `
    -Path 'C:\Users\DestinationUser\Documents\File.txt'

Information includes:

Owner
Inheritance status
Access rule count
Access rules
Test-ProfMigAcl

Validates whether an object has a suitable ACL for the destination user.

Example:

Test-ProfMigAcl `
    -Path 'C:\Users\DestinationUser\Documents\File.txt' `
    -DestinationSid $DestinationSid

The function reports:

Valid
DestinationUserAccess
SourceSidPresent
InheritanceEnabled
SystemAccessPresent
AdministratorsPresent
RemediationRequired
Findings
Error
Test-ProfMigParentAcl

Evaluates whether the parent directory can safely provide permissions through inheritance.

Example:

Test-ProfMigParentAcl `
    -Path 'C:\Users\DestinationUser\Documents\File.txt' `
    -DestinationSid $DestinationSid

The function reports whether inheritance from the parent is suitable.

Repair-ProfMigDestinationPermissions

Repairs destination permissions when required.

The preferred remediation order is:

Validate ACL
    |
    +-- Destination already has access
    |       |
    |       +-- No change
    |
    +-- Destination has no access
            |
            +-- Validate parent ACL
                    |
                    +-- Suitable parent
                    |       |
                    |       +-- Restore inheritance
                    |
                    +-- Access still unavailable
                            |
                            +-- Grant destination Modify

Every ACL change is followed by validation.

Logging

Permission validation and security changes use the central ProfMig logging framework when available.

Example validation log:

ACL validation:
Path='...'
DestinationSid='...'
Valid=False
DestinationAccess=False
InheritanceEnabled=False

Example security change:

Action='EnableInheritance'
Strategy='DestinationInheritance'

Example result:

ACL repair successful
Strategy='DestinationInheritance'
Destination access restored

Security changes are therefore visible and auditable.

CopyEngine Integration

ProfMig.CopyEngine.psm1 integrates the Sprint 3.5 permission engine.

The CopyEngine:

Resolves the destination profile SID.
Copies selected migration data.
Evaluates destination permissions.
Repairs permissions where necessary.
Records permission results.
Includes permission information in migration results.

Permission-related result properties include:

PermissionsChecked
PermissionsRepaired
PermissionWarnings
PermissionErrors
PermissionResults

This allows permission behaviour to be included in migration reporting.

End-to-End Verification

Sprint 3.5 includes:

tests/Test-ProfMigSprint35-EndToEnd.ps1

The test uses isolated data under the current user's temporary directory.

It does not modify production profile data.

The verification covers:

PowerShell syntax
Module loading
Destination SID resolution
Component copying
Security exclusions
Destination-user ACL access
SYSTEM permissions
Administrators permissions
Broken ACL detection
Inheritance remediation
Prevention of Everyone permissions
Prevention of unnecessary explicit destination ACEs
Source SID detection
CopyEngine integration
Verified Test Scenario

A deliberately broken ACL was created with:

DestinationUserAccess : False
InheritanceEnabled    : False
SystemAccessPresent   : False
AdministratorsPresent : False

ProfMig detected:

ACL-DESTINATION-NO-ACCESS
ACL-INHERITANCE-DISABLED
ACL-SYSTEM-MISSING
ACL-ADMINISTRATORS-MISSING

The remediation strategy selected:

Strategy : DestinationInheritance
Action   : EnableInheritance

After remediation:

DestinationUserAccess : True
InheritanceEnabled    : True

No Everyone ACE was introduced.

No unnecessary explicit destination-user ACE was introduced.

Security Validation

The Sprint 3.5 end-to-end test confirmed:

PASS Destination user can access migrated component
PASS SYSTEM access preserved
PASS Administrators access preserved
PASS Broken ACL detected
PASS ACL remediation succeeded
PASS Normal inheritance restored
PASS No Everyone permissions introduced
PASS No unnecessary explicit destination ACE
PASS Source SID is finding, not automatic remediation

The final test result was:

SPRINT 3.5 END-TO-END RESULT: PASS
All tested acceptance criteria passed.
Acceptance Criteria
Destination user can access migrated files

Verified.

Old source SID does not prevent access

Verified.

Source SID presence can be detected without automatically rewriting an otherwise valid ACL.

Normal Windows inheritance is preserved where appropriate

Verified.

Destination inheritance is the preferred remediation strategy.

ProfMig does not create overly permissive ACLs

Verified.

No Everyone Full Control or equivalent broad access is introduced.

Permission errors are logged

Implemented.

Permission validation, changes and failures are passed to the ProfMig logging framework.

ACL behaviour is documented

Implemented in this document.

Definition of Done

Sprint 3.5 is considered complete when migrated data receives predictable and secure permissions appropriate for the destination Windows user.

The implemented strategy:

Resolves Windows profile SIDs
Inspects NTFS ACLs
Validates destination access
Preserves normal Windows inheritance
Restores inheritance where safe
Uses explicit permissions only when necessary
Preserves SYSTEM and Administrators access
Avoids broad permission grants
Detects source SID entries
Logs ACL security changes
Integrates permission handling with the CopyEngine