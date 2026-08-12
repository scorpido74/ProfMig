# Microsoft Edge Migration

ProfMig provides controlled migration of supported Microsoft Edge profile data between Windows user profiles.

The Edge migration component is designed to migrate portable browser data while avoiding security-sensitive or user-bound information.

## Supported data

ProfMig currently migrates the following Microsoft Edge data:

- Favorites / Bookmarks
- Bookmarks backup
- Favicons
- Default Edge profile
- Multiple Edge profiles (`Profile 1`, `Profile 2`, etc.)

## Data requiring review

The following Edge data is detected but is not automatically migrated:

- Preferences
- History
- Extensions

These items may contain machine-specific, user-specific, version-specific, or otherwise non-portable configuration.

ProfMig reports these items as `Review`.

## Excluded security-sensitive data

ProfMig deliberately excludes security-sensitive Edge data, including:

- Saved passwords (`Login Data`)
- Cookies
- Autofill and payment information (`Web Data`)
- Browser sessions (`Sessions`)
- Session storage

ProfMig does not attempt to decrypt, re-encrypt, recover, or transfer credentials or authentication material.

## DPAPI

Microsoft Edge may protect user data using Windows Data Protection API (DPAPI) and other user-specific encryption mechanisms.

ProfMig:

- Does not bypass DPAPI
- Does not decrypt Edge credentials
- Does not transfer Windows user-bound encryption keys
- Does not attempt to make encrypted source-user data usable by another Windows user

Users must sign in again to websites and services where authentication information is not portable.

## Edge must be closed

Microsoft Edge must be closed before migration.

ProfMig detects whether Edge is running and prevents migration while the browser is active.

This reduces the risk of:

- Locked database files
- Inconsistent browser data
- Partially written files
- Profile corruption

## Existing destination profiles

The destination Edge profile may already contain data created by Edge.

ProfMig does not assume that the presence of files such as `Login Data`, `Cookies`, `History`, `Preferences`, or session data means those files were migrated from the source profile.

Migration validation therefore distinguishes between:

- Data explicitly migrated by ProfMig
- Data excluded from migration
- Data requiring review
- Data already present or independently created by Edge at the destination

## Destination data

Supported portable files may replace corresponding files in the destination Edge profile.

Migration to a clean or controlled destination profile is therefore recommended.

ProfMig does not currently merge two bookmark databases or browser profiles at the application-data level.

## Multiple Edge profiles

ProfMig detects and processes:

- `Default`
- `Profile 1`
- `Profile 2`
- Additional standard Edge profile directories

Each detected profile is processed independently according to the same migration and security rules.

## Validation

ProfMig validates supported migrated data after migration.

For items marked `Review` or `Exclude`, the existence of an equivalent file at the destination is not considered proof that ProfMig migrated it because Edge may have created that data independently.

## Reporting

Edge migration results are returned to the standard ProfMig reporting system.

Reports can contain:

- Selected Edge components
- Files copied
- Files skipped
- Files excluded
- Bytes copied
- Migration errors
- Security exclusion reasons
- Overall migration status

## Current limitations

The current Edge migration implementation does not migrate:

- Saved passwords
- Authentication tokens
- Cookies
- Active browser sessions
- Session storage
- Payment information
- Autofill information
- Preferences
- History
- Extensions

Future ProfMig versions may add migration support for additional Edge data where it can be demonstrated to be safe and portable between Windows users.