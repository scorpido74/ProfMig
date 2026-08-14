# Google Chrome Migration

## Overview

ProfMig provides controlled migration of Google Chrome profile data between Windows user profiles.

The Chrome migration component is designed to preserve useful and portable browser data without transferring protected credentials, authentication sessions or other user-bound security data.

ProfMig does not copy the complete Chrome `User Data` directory.

## Supported data

ProfMig currently supports migration of the following Chrome profile data where present:

- Bookmarks
- Bookmark backups
- Preferences
- History
- Favicons
- Shortcuts
- Top Sites

Chrome supports multiple browser profiles.

ProfMig detects:

- Default
- Profile 1
- Profile 2
- Additional `Profile *` directories

Profile display names are detected and recreated in the destination Chrome `Local State`.

## Multiple Chrome profiles

ProfMig detects all supported Chrome profiles in the source Windows profile.

During migration:

1. Each Chrome profile is processed individually.
2. Supported portable data is copied to the corresponding destination profile.
3. Protected data is excluded.
4. Chrome profile registration is recreated in the destination `Local State`.
5. Source Google account identity is not copied.

This allows Chrome to recognize migrated profiles without migrating the original user's Google authentication state.

## Chrome Local State

Chrome uses the following file to maintain browser-level configuration and profile registration:

`AppData\Local\Google\Chrome\User Data\Local State`

ProfMig does not blindly migrate the source `Local State`.

Instead, ProfMig creates destination profile registration containing neutral profile metadata required for Chrome to recognize the migrated profiles.

Google account identifiers and authentication state are not migrated.

## Extensions

Chrome extensions are inventoried during migration planning.

ProfMig records information including:

- Extension ID
- Extension name
- Installed version
- Number of installed versions

Extensions are currently classified as:

`InventoryOnly`

Extension packages and extension-specific state are not migrated.

This avoids transferring extension data that may contain:

- Authentication information
- Account-bound configuration
- Security tokens
- Protected extension storage
- User-specific secrets

Extensions must therefore be reinstalled or restored through Chrome, Google account synchronization or enterprise policy.

## Protected data

ProfMig explicitly excludes Chrome data that may contain credentials, authentication state, encryption material or other user-bound information.

Examples include:

- Login Data
- Login Data For Account
- Cookies
- Extension Cookies
- Sessions
- Session Storage
- Web Data
- Account Web Data
- Accounts
- Sync Data
- GCM Store
- ClientCertificates
- passkey_enclave_state
- trusted_vault.pb
- EncryptedBookmarks
- Secure Preferences
- Local Extension Settings
- Managed Extension Settings

ProfMig does not decrypt or attempt to migrate DPAPI-protected Chrome information.

## Passwords

Saved Chrome passwords are not migrated.

After migration, the destination user must authenticate again or use an approved password manager or Chrome synchronization mechanism.

## Authentication sessions

Existing website sessions are not migrated.

Users should expect to sign in again to websites and services after migration.

Google account authentication is also not migrated.

## Destination protection

ProfMig checks the destination Chrome profile before migration.

If supported Chrome files already exist and migration would overwrite them, the migration is blocked.

This prevents ProfMig from silently destroying existing destination Chrome data.

Merging existing source and destination Chrome profiles is not supported in the current release.

## Chrome process protection

Chrome must be closed before migration.

ProfMig checks for running Chrome processes and blocks migration while Chrome is running.

This prevents migration of files while Chrome databases or configuration files may be open.

## Source protection

ProfMig does not modify the source Chrome profile.

Source data is read only for:

- Detection
- Inventory
- Migration planning
- File copying

## Validation

The Chrome migration component validates:

- Source Windows profile exists
- Chrome is detected
- Chrome is not running
- Source and destination profiles differ
- Supported migration items are available
- Protected Chrome data is excluded
- Extensions remain inventory-only
- Destination data will not be overwritten

## Migration reporting

Chrome migration returns structured results to ProfMig including:

- Migration status
- Number of Chrome profiles
- Number of registered profiles
- Files selected
- Files copied
- Files failed
- Bytes copied
- Extensions detected
- Validation results
- Errors

## Tested migration

Sprint 2.3 validation included migration of a Chrome installation containing:

- 15 Chrome profiles
- 94 portable Chrome items
- 76 detected extensions

Migration result:

- 15 profiles detected
- 15 profiles registered
- 94 files selected
- 94 files copied
- 0 files failed
- Protected data excluded
- Extensions inventory-only

Chrome successfully recognized all migrated profiles in the destination Windows profile.

Bookmarks and browser history were successfully validated after migration.

Google authentication and saved credentials were not transferred.

## Known limitations

The current Chrome migration implementation does not:

- Migrate saved passwords
- Migrate cookies
- Migrate active browser sessions
- Migrate Google account authentication
- Migrate payment information
- Migrate passkeys
- Migrate DPAPI-protected data
- Migrate extension packages
- Migrate extension-specific state
- Merge existing source and destination Chrome profiles

These limitations are intentional unless otherwise stated and are part of the ProfMig security model.

## Security principles

The Chrome migration implementation follows these rules:

- Do not modify source data
- Do not decrypt credentials
- Do not bypass DPAPI
- Do not blindly copy the complete Chrome profile
- Explicitly allow portable data
- Explicitly exclude protected data
- Require reauthentication after migration