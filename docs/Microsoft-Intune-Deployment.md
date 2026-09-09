# Microsoft Intune Deployment

## Overview

ProfMig can be packaged and deployed as a Microsoft Intune Win32 application.

The Intune deployment process is designed to install, update, detect, and uninstall the ProfMig runtime on managed Windows endpoints without automatically starting a user profile migration.

This separation is intentional.

Intune deployment and profile migration are two different operations:

1. **Runtime deployment**
   - Install ProfMig.
   - Update ProfMig.
   - Detect the installed version.
   - Uninstall ProfMig.
   - Preserve persistent migration data where applicable.

2. **Profile migration**
   - Select source and destination profiles.
   - Validate the migration configuration.
   - Perform the actual profile migration.
   - Generate migration logs and reports.
   - Verify migrated data.

Installing or updating ProfMig through Intune must never automatically start a profile migration.

---

## Architecture

The Intune deployment architecture is:

```text
Microsoft Intune
       |
       v
ProfMig-<version>.intunewin
       |
       v
Deploy-ProfMig.ps1
       |
       v
C:\Program Files\ProfMig
       |
       +-- ProfMig.Build.psd1
       +-- Start-ProfMig.bat
       +-- Deploy-ProfMig.ps1
       +-- Uninstall-ProfMig.ps1
       +-- src\
       +-- Logs\
       +-- Reports\
       +-- Backup\
```

The runtime is installed by default in:

```text
C:\Program Files\ProfMig
```

The deployment process supports unattended execution and has been validated running as:

```text
NT AUTHORITY\SYSTEM
```

SYSTEM execution has been validated for:

- installation;
- version detection;
- version upgrade;
- persistent-data preservation during upgrade;
- uninstall.

SYSTEM has subsequently also been validated as an execution context for unattended silent profile migration. Runtime deployment and profile migration nevertheless remain separate operations, and all normal ProfMig migration validation remains mandatory.

The migration execution context must be validated separately because access to source profiles, destination profiles, user-specific resources, encryption material, application data, and ACLs can depend on the execution identity.

---

## Intune package components

The Intune build process produces two release artifacts.

### Win32 application package

```text
dist\Intune\Package\ProfMig-<version>.intunewin
```

Example:

```text
dist\Intune\Package\ProfMig-0.2.0.intunewin
```

This package contains the ProfMig runtime and deployment scripts.

### Detection script

```text
dist\Intune\Detection\Detect-ProfMig-<version>.ps1
```

Example:

```text
dist\Intune\Detection\Detect-ProfMig-0.2.0.ps1
```

The detection script is version-bound.

This means that the detection artifact generated for ProfMig 0.2.0 explicitly detects version 0.2.0.

The package and detection script should therefore always be kept together as release artifacts.

---

## Source package

Before creating the `.intunewin` file, ProfMig creates an Intune source package in:

```text
dist\Intune\ProfMig
```

The source package is created using:

```text
build\New-ProfMigPackage.ps1
```

The Intune-specific build orchestration is performed by:

```text
build\Intune\New-ProfMigIntunePackage.ps1
```

The resulting source directory contains the runtime files required on the endpoint.

Build output under `dist` is not intended to be committed to the Git repository.

---

## Building the Intune package

From the ProfMig repository root, run:

```powershell
.\build\Intune\New-ProfMigIntunePackage.ps1
```

The build process:

1. Reads the ProfMig version.
2. Creates the runtime package.
3. Validates required runtime components.
4. Creates a version-bound Intune detection script.
5. Runs the Microsoft Win32 Content Prep Tool.
6. Creates the `.intunewin` package.
7. Renames the package using the ProfMig version.

Example output:

```text
dist\Intune\Package\ProfMig-0.2.0.intunewin
dist\Intune\Detection\Detect-ProfMig-0.2.0.ps1
```

---

## Source-only build

The Intune source package and detection script can be generated without creating the final `.intunewin` file.

Use:

```powershell
.\build\Intune\New-ProfMigIntunePackage.ps1 -SourceOnly
```

This is useful for:

- development;
- package inspection;
- automated testing;
- detection testing;
- environments where the Microsoft Win32 Content Prep Tool is not installed.

The Microsoft packaging utility is therefore not required to develop or test the ProfMig runtime itself.

---

## Microsoft Win32 Content Prep Tool

The final `.intunewin` package is created using the Microsoft Win32 Content Prep Tool.

The executable used by the ProfMig build process is expected by default at:

```text
build\Tools\IntuneWinAppUtil.exe
```

The `build\Tools` directory is excluded from Git.

The Microsoft utility is an external build dependency and is not distributed as part of the ProfMig repository.

It is also not installed on ProfMig endpoints.

It is only required on the workstation or build system used to create the `.intunewin` package.

The path can be overridden when required by using the appropriate parameter of `New-ProfMigIntunePackage.ps1`.

During Sprint 5.5 the Intune packaging process was validated with:

```text
Microsoft Win32 Content Prep Tool release: 1.8.7
Executable file/product version: 6.2509.50.0
Digital signature: Microsoft Corporation
Signature status: Valid
```

This version represents the validated Sprint 5.5 build environment and is not intended as a permanent minimum or maximum supported version.

A newer Microsoft-supported version of the Win32 Content Prep Tool can be used after validation.

---

## Build metadata

Each ProfMig runtime package contains:

```text
ProfMig.Build.psd1
```

This file provides package metadata including:

```text
Name
Version
Build
GitCommit
GitDirty
BuiltAt
```

Example:

```powershell
@{
    Name      = 'ProfMig'
    Version   = '0.2.0'
    Build     = 'Development'
    GitCommit = '<git-commit>'
    GitDirty  = $False
    BuiltAt   = '<build-timestamp>'
}
```

The build metadata is used for:

- deployment validation;
- installed-version detection;
- upgrade decisions;
- downgrade protection;
- Intune detection.

For release builds, the package should preferably be created from a clean Git working tree so that:

```text
GitDirty = False
```

---

## Version source

The ProfMig application version is defined in:

```text
src\Config.psd1
```

The relevant configuration is:

```powershell
Application = @{
    Version = '0.2.0'
    Build   = 'Development'
}
```

The Intune package builder reads this version through the existing ProfMig packaging process.

The same version is then used for:

- runtime metadata;
- `.intunewin` naming;
- generated detection script naming;
- expected installed version.

This reduces the risk of deploying one ProfMig version with a detection rule intended for another version.

---

## Intune Win32 application configuration

Create a Windows Win32 application in Microsoft Intune and upload:

```text
ProfMig-<version>.intunewin
```

Example:

```text
ProfMig-0.2.0.intunewin
```

### Install command

Use:

```text
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\Deploy-ProfMig.ps1
```

### Uninstall command

Use:

```text
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\Uninstall-ProfMig.ps1
```

The uninstall command preserves persistent ProfMig data by default.

### Install behavior

Use:

```text
System
```

SYSTEM execution has been validated during Sprint 5.5 for runtime installation, detection, upgrade, and uninstall.

### Device restart behavior

ProfMig does not normally require a Windows restart for runtime installation or uninstall.

Use an Intune restart behavior appropriate for applications that do not initiate a device restart.

---

## Requirements

The ProfMig Intune package is intended for managed Windows endpoints capable of running the ProfMig PowerShell runtime.

The deployment process assumes:

- Windows endpoint;
- Windows PowerShell available;
- administrative/SYSTEM deployment context;
- access to `C:\Program Files`;
- sufficient storage for the ProfMig runtime;
- Intune Management Extension available for Win32 application deployment.

The requirements for the actual profile migration can be stricter than the requirements for installing the runtime.

Deployment requirements must therefore not be treated as complete migration prerequisites.

---

## Detection rule

Use a custom detection script in Intune.

Upload the version-specific detection artifact:

```text
Detect-ProfMig-<version>.ps1
```

Example:

```text
Detect-ProfMig-0.2.0.ps1
```

No command-line parameters are required when the generated detection script is used by Intune.

The generated script contains its expected ProfMig version.

---

## Detection logic

Detection is based on:

```text
C:\Program Files\ProfMig\ProfMig.Build.psd1
```

For detection to succeed:

1. The ProfMig installation path must exist.
2. `ProfMig.Build.psd1` must exist.
3. The metadata name must be `ProfMig`.
4. The metadata must contain a version.
5. The installed version must exactly match the expected version.

A successful detection produces output similar to:

```text
ProfMig 0.2.0 detected at C:\Program Files\ProfMig
```

and exits with:

```text
0
```

A missing, invalid, or different version exits with:

```text
1
```

This allows Intune to distinguish between:

- the requested ProfMig version being installed;
- another ProfMig version being installed;
- ProfMig not being installed;
- only persistent ProfMig data remaining after uninstall.

---

## Generic detection template

The repository also contains:

```text
build\Intune\Detect-ProfMig.ps1
```

This is the generic detection implementation used by the build process.

It accepts:

```powershell
-ExpectedVersion
```

and optionally:

```powershell
-InstallPath
```

Example for development or testing:

```powershell
.\build\Intune\Detect-ProfMig.ps1 `
    -ExpectedVersion '0.2.0' `
    -InstallPath 'C:\Program Files\ProfMig'
```

For production Intune configuration, use the generated version-specific detection script instead.

---

## Deployment behavior

`Deploy-ProfMig.ps1` supports:

- clean installation;
- reinstall;
- upgrade;
- downgrade protection;
- staging;
- validation before activation;
- rollback behavior;
- preservation of persistent data.

The default installation path is:

```text
C:\Program Files\ProfMig
```

The deployment process stages and validates the new runtime before activating it.

This prevents an incomplete package from immediately replacing a working ProfMig installation.

---

## Upgrade behavior

ProfMig supports replacement of an existing runtime with a newer runtime.

The deployment script determines the currently installed version using:

```text
C:\Program Files\ProfMig\ProfMig.Build.psd1
```

The package version is then compared with the installed version.

The deployment process is designed to:

1. Validate the new package.
2. Detect the existing installation.
3. Determine whether the deployment is an install, reinstall, upgrade, or downgrade.
4. Stage the replacement runtime.
5. Preserve the current installation for rollback.
6. Activate the new runtime.
7. Restore persistent data.
8. Validate the resulting installation.

During Sprint 5.5, a real SYSTEM-context upgrade was validated using:

```text
ProfMig 0.1.0
      |
      v
NT AUTHORITY\SYSTEM
      |
      v
Deploy-ProfMig.ps1
      |
      v
ProfMig 0.2.0
```

The upgrade completed successfully with Windows Scheduled Task result:

```text
0
```

After the upgrade:

- installed version metadata reported `0.2.0`;
- Logs were preserved;
- Reports were preserved;
- Backup data was preserved;
- runtime-only content from the previous installation was removed.

This confirms that the deployment mechanism replaces the ProfMig runtime rather than simply copying new files over the previous installation.

---

## Downgrade protection

ProfMig deployment blocks a downgrade by default.

For example, if version:

```text
0.3.0
```

is installed and package:

```text
0.2.0
```

is deployed, the deployment should reject the downgrade.

A downgrade can only be explicitly allowed using:

```powershell
-AllowDowngrade
```

This option is not part of the normal Intune installation command.

Normal Intune deployment should therefore retain downgrade protection.

---

## Persistent data

ProfMig currently treats the following installation directories as persistent data:

```text
C:\Program Files\ProfMig\Logs
C:\Program Files\ProfMig\Reports
C:\Program Files\ProfMig\Backup
```

These directories are preserved during supported runtime replacement operations where applicable.

During a normal uninstall, these directories are also preserved.

Runtime files are removed or replaced while persistent data remains available.

This behavior is intended to prevent diagnostic and migration information from being destroyed automatically during:

- uninstall;
- reinstall;
- upgrade;
- runtime replacement.

Persistent-data preservation during an upgrade from 0.1.0 to 0.2.0 under SYSTEM was validated during Sprint 5.5.

---

## Full data removal

`Uninstall-ProfMig.ps1` supports explicit removal of persistent data using:

```powershell
-RemoveData
```

This should only be used when intentional removal of ProfMig data is required.

The standard Intune uninstall command does **not** use this parameter.

As a result, removing the Intune application does not automatically delete Logs, Reports, or Backup data.

---

## Detection after uninstall

The presence of persistent directories does not count as a valid ProfMig installation.

For example, the following directories can remain:

```text
C:\Program Files\ProfMig\Logs
C:\Program Files\ProfMig\Reports
C:\Program Files\ProfMig\Backup
```

while detection still correctly reports ProfMig as not installed.

This works because detection is based on valid runtime metadata rather than only the existence of the installation directory.

---

## Exit codes

### Deployment

`Deploy-ProfMig.ps1` uses the following deployment exit codes:

| Exit code | Meaning |
|---:|---|
| 0 | Success |
| 1 | General failure |
| 2 | Administrator required |
| 3 | Invalid package |
| 4 | Downgrade blocked |

Intune should treat exit code `0` as success.

Non-zero exit codes indicate that the deployment did not complete successfully.

### Uninstall

`Uninstall-ProfMig.ps1` uses:

| Exit code | Meaning |
|---:|---|
| 0 | Success |
| 1 | General failure |
| 2 | Administrator required |
| 3 | Invalid installation |

### Detection

The generated detection script uses:

| Exit code | Meaning |
|---:|---|
| 0 | Expected ProfMig version detected |
| 1 | Not detected, invalid installation, or different version |

A successful detection also writes output to standard output as required by the Intune custom detection model.

---

## Silent and unattended execution

The Intune deployment commands use:

```text
-NoProfile
-NonInteractive
-ExecutionPolicy Bypass
```

The deployment process must not require:

- interactive administrator input;
- user confirmation;
- tenant credentials;
- profile selection;
- migration configuration input.

The runtime deployment process has been tested without interactive input.

Profile migration is intentionally not started by the installation process.

---

## Execution context

### Runtime deployment

The following operations were validated under:

```text
NT AUTHORITY\SYSTEM
```

- ProfMig installation;
- version detection;
- version upgrade;
- persistent-data preservation during upgrade;
- uninstall.

The SYSTEM test environment reported:

```text
USERNAME=<computer-account>$
USERPROFILE=C:\WINDOWS\system32\config\systemprofile
ProgramFiles=C:\Program Files
```

This confirms that the tests used the Windows SYSTEM security context rather than the interactive administrator account.

### Profile migration

SYSTEM validation for runtime deployment must not be interpreted as validation for profile migration.

A profile migration can involve:

- source user profile access;
- destination user profile access;
- ACL changes;
- user-specific application data;
- locked files;
- browser data;
- Outlook data;
- profile ownership;
- SID-specific resources.

The destination profile must not be assumed to be owned by SYSTEM.

ProfMig migration logic must continue to perform its existing validation and permission checks regardless of how the runtime was deployed.

No migration validation or security control may be bypassed because the application was installed through Intune.

During Sprint 5.5, SYSTEM was also validated as an execution context for an actual unattended silent migration between dedicated test profiles.

The migration was executed without using `-SkipPrivilegeCheck`, `-SkipDiskSpaceCheck`, or another validation bypass.

The test confirmed:

- successful source profile resolution;
- successful destination profile resolution;
- successful pre-migration validation;
- successful migration of Desktop and Documents test data;
- `DestinationAccess=True` during destination ACL validation;
- inherited destination-user access remained valid;
- copied test files matched their source using SHA256;
- no verification failures occurred.

The copied files were owned by:

```text
NT AUTHORITY\SYSTEM

The destination user retained inherited:

FullControl

This demonstrates that SYSTEM is a supported unattended migration execution context for the validated scenario.

It does not make migration validation optional. ProfMig must continue to validate the actual source profile, destination profile, privileges, storage, permissions, ACLs and verification requirements for every migration.


### Exitcodes expliciet scheiden

ProfMig uses different exit-code contracts for deployment, migration and Intune detection.

These values must be interpreted in the context of the component that returned them. In particular, exit code `1` has a different meaning for runtime deployment and profile migration.

| Component | Exit code 0 | Exit code 1 |
|---|---|---|
| `Deploy-ProfMig.ps1` | Success | General deployment failure |
| `ProfMig.ps1 -Silent` | Success | Success with warnings |
| Intune detection script | Expected version detected | Not detected or version mismatch |

A management platform must therefore not apply the deployment exit-code interpretation to a separately executed profile migration.

For silent migration, exit code `1` is a successful migration result with warnings and should be handled as such by the orchestration platform.

---

## Logging and reports

ProfMig maintains runtime and migration information in its existing logging and reporting locations.

The current persistent locations are:

```text
C:\Program Files\ProfMig\Logs
C:\Program Files\ProfMig\Reports
C:\Program Files\ProfMig\Backup
```

These directories are preserved by the standard uninstall process and during validated runtime upgrades.

Deployment through Intune must not introduce sensitive information into deployment output or logs.

Existing ProfMig controls for sensitive-data logging remain applicable.

Intune deployment should not weaken or bypass those controls.

---

## Validated Sprint 5.5 lifecycle

During Sprint 5.5, the Intune deployment lifecycle was tested using Windows Scheduled Tasks running as:

```text
NT AUTHORITY\SYSTEM
```

This provided a reproducible SYSTEM execution context without requiring the Intune service itself during local development.

The following lifecycle was validated:

```text
Build Intune package
        |
        v
Install ProfMig 0.2.0 as SYSTEM
        |
        v
Detect ProfMig 0.2.0
        |
        v
Reject incorrect version 0.3.0
        |
        v
Uninstall ProfMig as SYSTEM
        |
        v
Verify Logs / Reports / Backup are preserved
        |
        v
Verify ProfMig is no longer detected
        |
        v
Install controlled 0.1.0 baseline as SYSTEM
        |
        v
Create persistent-data test markers
        |
        v
Upgrade 0.1.0 -> 0.2.0 as SYSTEM
        |
        v
Verify installed version is 0.2.0
        |
        v
Verify Logs / Reports / Backup are preserved
        |
        v
Verify old runtime-only content is removed
```

### Validated results

| Test | Result |
|---|---|
| Intune source package creation | PASS |
| `.intunewin` package creation | PASS |
| Version-specific package naming | PASS |
| Version-specific detection generation | PASS |
| Silent SYSTEM installation | PASS |
| Correct version detection under SYSTEM | PASS |
| Detection without external parameters | PASS |
| Incorrect version rejected | PASS |
| SYSTEM uninstall | PASS |
| Logs preserved after uninstall | PASS |
| Reports preserved after uninstall | PASS |
| Backup preserved after uninstall | PASS |
| Runtime removed during uninstall | PASS |
| Detection fails after uninstall | PASS |
| SYSTEM installation of controlled 0.1.0 baseline | PASS |
| SYSTEM upgrade from 0.1.0 to 0.2.0 | PASS |
| Installed version after upgrade is 0.2.0 | PASS |
| Logs preserved during upgrade | PASS |
| Reports preserved during upgrade | PASS |
| Backup preserved during upgrade | PASS |
| Previous runtime-only content removed during upgrade | PASS |
| Upgrade package built from clean Git state | PASS |
| SYSTEM silent profile migration | PASS |
| Pre-migration validation under SYSTEM | PASS |
| Destination ACL validation under SYSTEM | PASS |
| DestinationAccess=True | PASS |
| SYSTEM migration SHA256 verification | PASS |
| Destination user retained FullControl | PASS |
| Migration validation bypass required | NO |

### Upgrade validation details

The upgrade validation used a controlled 0.1.0 deployment baseline followed by the clean 0.2.0 runtime package.

The 0.2.0 upgrade package was built from Git commit:

```text
84c5b88817c71189f0dbdfd4a36a0420f23b2744
```

with:

```text
GitDirty = False
```

The upgrade was executed under:

```text
NT AUTHORITY\SYSTEM
```

and completed successfully with Windows Scheduled Task result:

```text
0
```

Before the upgrade, persistent test markers were created in:

```text
Logs
Reports
Backup
```

A separate runtime-only marker was created in the root of the 0.1.0 installation.

After upgrading to 0.2.0:

- all three persistent test markers remained present;
- the installed metadata reported version `0.2.0`;
- the runtime-only 0.1.0 marker was no longer present.

This validates both persistent-data preservation and runtime replacement during the upgrade.

---

## Sprint 5.5 test package

The validated 0.2.0 runtime package contained:

```text
Version: 0.2.0
Build: Development
GitCommit: 84c5b88817c71189f0dbdfd4a36a0420f23b2744
GitDirty: False
```

The generated Win32 package was:

```text
ProfMig-0.2.0.intunewin
```

The generated detection artifact was:

```text
Detect-ProfMig-0.2.0.ps1
```

The functional deployment tests were performed against version 0.2.0.

The controlled 0.1.0 package used for the upgrade baseline was created specifically for upgrade validation.

The final release artifacts should always be rebuilt from the final committed source so that their build metadata accurately represents the repository state.

---

## Intune upgrade configuration

When publishing a new ProfMig version, generate a new package:

```text
ProfMig-<new-version>.intunewin
```

and its corresponding detection script:

```text
Detect-ProfMig-<new-version>.ps1
```

Do not reuse an old detection script for a new package version.

Example:

```text
ProfMig-0.3.0.intunewin
Detect-ProfMig-0.3.0.ps1
```

The package and detection artifact should be treated as one release pair.

The ProfMig deployment upgrade mechanism has been validated under SYSTEM during Sprint 5.5.

Where Intune supersedence is used, the new ProfMig Win32 application can supersede the previous application.

Intune supersedence configuration itself should still be validated in the target Intune environment before production rollout.

---

## Recommended Intune configuration

For a normal ProfMig runtime deployment, use the following configuration:

| Setting | Value |
|---|---|
| Application type | Windows app (Win32) |
| Package | `ProfMig-<version>.intunewin` |
| Install behavior | System |
| Install command | `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\Deploy-ProfMig.ps1` |
| Uninstall command | `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\Uninstall-ProfMig.ps1` |
| Detection type | Custom detection script |
| Detection script | `Detect-ProfMig-<version>.ps1` |
| Automatic migration during install | No |
| Persistent data removal during normal uninstall | No |

---

## Security considerations

Intune deployment does not change ProfMig's migration security model.

The following principles remain mandatory:

- No tenant credentials are stored in the package.
- No interactive administrator credentials are required.
- No migration starts automatically after deployment.
- Existing validation controls remain enabled.
- Existing storage checks remain enabled.
- Existing permission and ACL checks remain enabled.
- Existing error handling remains enabled.
- Existing migration verification remains enabled.
- Sensitive information must not be written unnecessarily to deployment output.
- SYSTEM ownership of a destination profile must never be assumed.
- Deployment success must not be treated as migration validation success.

The purpose of Intune deployment is to make the ProfMig runtime available on the endpoint in a controlled and repeatable way.

It does not authorize or configure a profile migration by itself.

---

## Operational workflow

A recommended operational workflow is:

```text
1. Build ProfMig release
          |
2. Generate Intune package
          |
3. Publish Win32 application
          |
4. Deploy runtime as SYSTEM
          |
5. Intune detects expected version
          |
6. Administrator / migration process
   selects migration configuration
          |
7. ProfMig performs validation
          |
8. Profile migration starts
          |
9. Verification and reporting
```

This separation makes it possible to deploy ProfMig to endpoints in advance without immediately changing user profiles.

---

## Troubleshooting

### ProfMig is not detected

Verify that:

```text
C:\Program Files\ProfMig\ProfMig.Build.psd1
```

exists.

Check that:

```text
Name = ProfMig
```

and that the installed version exactly matches the version expected by the detection script.

For example, a detection script for:

```text
0.3.0
```

must not detect:

```text
0.2.0
```

as compliant.

### Persistent directories remain after uninstall

This is expected behavior.

The standard uninstall preserves:

```text
Logs
Reports
Backup
```

Their presence does not mean ProfMig is still installed.

Detection should return not detected after the runtime metadata has been removed.

### Intune package cannot be created

Verify that:

```text
build\Tools\IntuneWinAppUtil.exe
```

exists.

Alternatively, create only the source package using:

```powershell
.\build\Intune\New-ProfMigIntunePackage.ps1 -SourceOnly
```

### Downgrade fails

This is expected when an older ProfMig package is deployed over a newer installed version.

Downgrades are blocked by default.

Investigate why the older package is being assigned before considering the explicit downgrade override.

### Deployment succeeds but migration cannot access a profile

Deployment success only proves that the ProfMig runtime was installed.

It does not prove that the execution identity selected for the actual migration has access to the source and destination profiles.

Profile access and migration execution context must be investigated separately.

---

## Release checklist

Before publishing a ProfMig Intune release:

- [ ] Git working tree is clean.
- [ ] ProfMig version is correct.
- [ ] Runtime tests pass.
- [ ] Intune source package builds successfully.
- [ ] `.intunewin` package builds successfully.
- [ ] Version-specific detection script is generated.
- [ ] Package version matches detection version.
- [ ] Install command is verified.
- [ ] Uninstall command is verified.
- [ ] SYSTEM installation is validated.
- [ ] SYSTEM detection is validated.
- [ ] Persistent data behavior is validated.
- [ ] Upgrade path is validated.
- [ ] No migration is automatically started.
- [ ] No security or validation control is bypassed.
- [ ] Final package is rebuilt from committed source.

The checklist is intended to be completed for each release. The completed Sprint 5.5 validation documented above does not remove the need to repeat the appropriate checks for future ProfMig versions.

---

## Related files

Build and deployment:

```text
build\New-ProfMigPackage.ps1
build\Deploy-ProfMig.ps1
build\Uninstall-ProfMig.ps1
build\Intune\New-ProfMigIntunePackage.ps1
build\Intune\Detect-ProfMig.ps1
```

Tests:

```text
tests\Test-ProfMigDeployment.ps1
tests\Test-ProfMigUninstall.ps1
tests\Test-ProfMigVersioning.ps1
tests\Test-ProfMigIntuneDetection.ps1
```

Related documentation:

```text
docs\Deployment-and-Update-Strategy.md
docs\Versioning-and-Build-Information.md
```

---

## Status

Microsoft Intune runtime deployment is supported by the Sprint 5.5 implementation.

The following capabilities have been implemented and validated:

- Win32 source packaging;
- `.intunewin` generation;
- version-specific detection;
- silent installation;
- SYSTEM runtime deployment;
- SYSTEM detection;
- SYSTEM uninstall;
- persistent data preservation;
- version-aware deployment;
- SYSTEM-context upgrade validation;
- persistent-data preservation during SYSTEM upgrade;
- runtime replacement during SYSTEM upgrade;
- downgrade protection.

Actual profile migration execution remains intentionally separate from runtime deployment.

SYSTEM has been validated for unattended silent migration using dedicated test profiles. The validation confirmed successful pre-migration validation, copy execution, SHA256 verification and destination-user access without bypassing ProfMig security or migration controls.