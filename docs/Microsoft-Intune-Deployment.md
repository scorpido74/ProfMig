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
- uninstall.

This validation does **not** imply that the actual user profile migration should run as SYSTEM.

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

SYSTEM execution has been validated during Sprint 5.5 for runtime deployment.

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

During a normal uninstall these directories are preserved.

Runtime files are removed while these directories remain available.

This behavior is intended to prevent diagnostic and migration information from being destroyed automatically during:

- uninstall;
- reinstall;
- runtime replacement.

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

---

## Logging and reports

ProfMig maintains runtime and migration information in its existing logging and reporting locations.

The current persistent locations are:

```text
C:\Program Files\ProfMig\Logs
C:\Program Files\ProfMig\Reports
C:\Program Files\ProfMig\Backup
```

These directories are preserved by the standard uninstall process.

Deployment through Intune must not introduce sensitive information into deployment output or logs.

Existing ProfMig controls for sensitive-data logging remain applicable.

Intune deployment should not weaken or bypass those controls.

---

## Validated Sprint 5.5 lifecycle

During Sprint 5.5, the Intune deployment lifecycle was tested using a Windows Scheduled Task running as:

```text
NT AUTHORITY\SYSTEM
```

This provided a reproducible SYSTEM execution context without requiring the Intune service itself during local development.

The following lifecycle was validated:

```text
Build Intune package
        |
        v
Install under SYSTEM
        |
        | exit 0
        v
Detect installed 0.2.0
        |
        | exit 0
        v
Detect incorrect 0.3.0
        |
        | exit 1
        v
Uninstall under SYSTEM
        |
        | exit 0
        v
Preserve Logs / Reports / Backup
        |
        v
Detect 0.2.0 after uninstall
        |
        | exit 1
        v
Not installed
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
| Logs preserved | PASS |
| Reports preserved | PASS |
| Backup preserved | PASS |
| Runtime removed | PASS |
| Detection fails after uninstall | PASS |

---

## Sprint 5.5 test package

The package used during the validated lifecycle contained:

```text
Version: 0.2.0
Build: Development
```

The generated Win32 package was:

```text
ProfMig-0.2.0.intunewin
```

The generated detection artifact was:

```text
Detect-ProfMig-0.2.0.ps1
```

The functional tests were performed against this version.

A development build can contain:

```text
GitDirty = True
```

when it is generated while local changes are present.

Final release artifacts should be rebuilt from the final committed source so the build metadata accurately represents the repository state.

---

## Upgrade strategy

Intune can deploy a newer ProfMig runtime over an existing installation.

The deployment script determines the currently installed version using:

```text
C:\Program Files\ProfMig\ProfMig.Build.psd1
```

The new package version is compared with the installed version.

The deployment process is designed to:

1. Validate the new package.
2. Detect the existing installation.
3. Preserve persistent data.
4. Stage the replacement runtime.
5. Activate the new runtime.
6. Validate the resulting installation.
7. Retain rollback protection where applicable.

The Intune detection script for the new release detects only the new expected version.

This means that an endpoint with an older ProfMig version does not satisfy the detection rule for the newer application version.

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

Where Intune supersedence is used, the new ProfMig Win32 application can supersede the previous application after the upgrade path has been validated.

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

Verify:

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
- downgrade protection.

Actual profile migration execution remains intentionally separate from runtime deployment and requires its own execution-context validation.