# ProfMig Versioning and Build Information

## Overview

ProfMig uses centralized version and build information so that every execution,
migration report, log file, package, and release can be associated with the
software version that produced it.

The authoritative application version is defined in:

`src\Config.psd1`

No separate manually maintained version file is used.

---

## Authoritative version source

The ProfMig application version is defined under the `Application` section of
`src\Config.psd1`:

```powershell
Application = @{
    Name    = 'ProfMig'
    Version = '0.2.0'
    Build   = 'Development'
}

Application.Version is the single authoritative source for the ProfMig
software version.

Application.Build identifies the type or purpose of the build and is not a
second version number.

Other components must consume these values rather than define their own
ProfMig application version.

Version format

ProfMig uses a Semantic Versioning based format:

MAJOR.MINOR.PATCH[-PRERELEASE]

Examples:

0.5.0
0.5.0-alpha
0.5.0-beta
0.5.0-rc1
0.5.0-rc.1

Versions such as the following are rejected:

1.0
v1.0.0
1
abc

The v prefix is reserved for Git tags and GitHub releases and is not stored
in Application.Version.

ProfMig does not currently use Semantic Versioning build metadata such as
0.5.0+build.123.

Build traceability is recorded separately through ProfMig build metadata.

Command-line version information

The ProfMig version can be displayed without starting a migration:

.\ProfMig.ps1 -Version

Example:

ProfMig 0.2.0
Build: Development

The version option can also be used with silent mode:

.\ProfMig.ps1 -Silent -Version

Version information is read from the central ProfMig configuration.

Logging

After logging has been initialized, ProfMig records the application version
and build identifier.

Example:

[09:49:23] [INFO] ProfMig version: 0.2.0
[09:49:23] [INFO] ProfMig build: Development

This makes it possible to determine which ProfMig version produced a log file.

Migration reports

Migration results and generated migration reports contain:

ProfMigVersion
ProfMigBuild

Human-readable reports include:

ProfMig version : 0.2.0
ProfMig build   : Development

This associates migration evidence with the ProfMig build that performed the
migration.

Runtime package metadata

The packaging process generates:

ProfMig.Build.psd1

This file is included in the root of every ProfMig runtime package.

Example:

@{
    Name      = 'ProfMig'
    Version   = '0.2.0'
    Build     = 'Development'
    GitCommit = 'eeb51eefaf6271cc0df546224fd5187760dbbb7b'
    GitDirty  = $true
    BuiltAt   = '2026-09-08T06:36:19.4385057Z'
}

The metadata fields have the following meaning:

Field	Description
Name	Application name
Version	ProfMig application version
Build	Build identifier
GitCommit	Git commit from which the package was created
GitDirty	Indicates whether the working tree contained uncommitted changes
BuiltAt	UTC timestamp at which the package was created

ProfMig.Build.psd1 is generated during packaging. It is not an authoritative
version source and must not be manually maintained.

Clean and dirty builds

A package created while the Git working tree contains uncommitted changes is
marked:

GitDirty = $true

Such packages can be used for development and testing, but must not be treated
as reproducible release artifacts.

Official release packages must be created from a clean Git working tree:

GitDirty = $false

This ensures that the recorded GitCommit corresponds to the source used to
create the release package.

Git tags and GitHub releases

ProfMig Git tags and GitHub releases use the application version with a v
prefix.

Examples:

Application.Version	Git tag / GitHub release
0.5.0	v0.5.0
0.5.0-beta	v0.5.0-beta
0.5.0-rc1	v0.5.0-rc1

The value stored in Application.Version never includes the v prefix.

A release therefore has the following relationship:

Config.psd1
Application.Version = 0.5.0
          |
          v
Git tag = v0.5.0
          |
          v
GitHub release = v0.5.0
          |
          v
ProfMig.Build.psd1
Version   = 0.5.0
GitCommit = <tagged commit>
GitDirty  = false
Release procedure

Before creating an official ProfMig release:

Set Application.Version in src\Config.psd1 to the intended version.
Run the ProfMig regression tests.
Commit all release changes.
Verify that the Git working tree is clean.
Create the Git tag v<Application.Version>.
Build the runtime package from the tagged commit.
Verify ProfMig.Build.psd1.
Confirm that GitDirty is $false.
Confirm that GitCommit matches the tagged commit.
Publish the corresponding GitHub release using the same tag.

Development packages may be created from a dirty working tree, but official
release packages must always be created from a clean source state.

Validation

Versioning behaviour is covered by:

tests\Test-ProfMigVersioning.ps1

The test validates:

Central version and build configuration
Valid release and pre-release version formats
Rejection of invalid version formats
CLI version output
Silent CLI version output
Version and build logging
Migration result metadata
Migration report metadata
Runtime package creation
Package version and build metadata
Git commit information
Git working tree state
Build timestamp

The test returns exit code 0 when all checks pass and exit code 1 when one
or more checks fail.