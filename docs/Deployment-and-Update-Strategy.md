# ProfMig Deployment and Update Strategy

## 1. Overview

ProfMig is distributed as a self-contained Windows runtime package.

The deployment model is designed so that an administrator does not need:

- Git
- a cloned ProfMig repository
- development files
- test files
- manual PowerShell module installation

The runtime package can be copied to a Windows system and installed locally or
through an RMM or software-distribution platform.

The default installation directory is:

    C:\Program Files\ProfMig

An alternative installation directory can be specified when required.

The deployment strategy supports:

- clean installation
- same-version detection
- upgrades
- controlled downgrades
- transactional deployment with rollback
- preservation of runtime data
- reinstall after application removal
- unattended deployment
- unattended uninstall
- complete removal when explicitly requested

---

## 2. Deployment Architecture

The ProfMig deployment flow is:

    Git repository
        |
        v
    New-ProfMigPackage.ps1
        |
        v
    ProfMig runtime package
        |
        v
    Deploy-ProfMig.ps1
        |
        v
    C:\Program Files\ProfMig
        |
        +--> Interactive mode
        |
        +--> Command-line mode
        |
        +--> Silent mode

The release package is created from the development repository, but the
resulting package does not depend on that repository.

After the package has been created, it can be copied to another Windows system
and deployed independently.

---

## 3. Creating the Runtime Package

The runtime package is created with:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\build\New-ProfMigPackage.ps1

The default output location is:

    dist\ProfMig

An alternative package location can be specified:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\build\New-ProfMigPackage.ps1 `
        -OutputPath 'C:\Packages\ProfMig'

The build process validates the required runtime components before creating the
package.

Existing package output is removed before a new package is created.

---

## 4. Runtime Package Contents

A ProfMig runtime package contains the application files required to deploy and
run ProfMig.

Typical structure:

    ProfMig\
    |
    +-- Deploy-ProfMig.ps1
    +-- Uninstall-ProfMig.ps1
    +-- Start-ProfMig.bat
    +-- ProfMig.Build.psd1
    +-- LICENSE
    |
    +-- src\
    |   +-- ProfMig.ps1
    |   +-- Config.psd1
    |   +-- Modules\
    |   +-- Applications\
    |   +-- Profiles\
    |
    +-- Logs\
    +-- Reports\

Development-only content is excluded from the package.

Examples include:

- .git
- .github
- tests
- docs
- TestData
- existing backup data
- existing logs
- existing reports

The package includes empty Logs and Reports directories. The Backup directory is
created by deployment when required.

---

## 5. Build Metadata

Each runtime package contains:

    ProfMig.Build.psd1

This file identifies the package and contains build information such as:

- application name
- version
- build identifier
- Git commit
- Git working-tree state at build time
- build timestamp

Deployment uses this metadata to determine the package version and the version
of an existing ProfMig installation.

ProfMig versions used by the deployment mechanism must use semantic version
format.

Examples:

    0.2.0
    0.3.0
    1.0.0
    1.0.0-beta.1

---

## 6. Administrator Requirement

Deployment requires administrator privileges.

The administrator check is performed before the package modifies the target
system.

If ProfMig deployment is started without administrator privileges, deployment
stops with exit code:

    2

No installation directory is created by the rejected deployment.

Uninstall also requires administrator privileges.

This makes the scripts suitable for RMM and software-distribution platforms
that execute deployment actions in an elevated or system context.

---

## 7. Clean Installation

To install ProfMig using the default installation directory:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Deploy-ProfMig.ps1

Default destination:

    C:\Program Files\ProfMig

To use another location:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Deploy-ProfMig.ps1 `
        -InstallPath 'D:\Applications\ProfMig'

Before changing the system, the deployment script validates the package.

Required runtime components include:

- ProfMig.Build.psd1
- Start-ProfMig.bat
- LICENSE
- src\ProfMig.ps1
- src\Config.psd1
- src\Modules
- src\Applications
- src\Profiles

An invalid or incomplete package is rejected before installation.

---

## 8. Installed Runtime Data

The following directories are considered persistent runtime data:

    Logs
    Reports
    Backup

Deployment ensures these directories exist in the installed ProfMig
environment.

Persistent data is treated differently from application binaries because it
may contain information that must survive an upgrade or normal uninstall.

---

## 9. Same-Version Deployment

When the package version is identical to the installed version, deployment
does not replace the existing installation.

Example:

    Installed: 0.2.0
    Package:   0.2.0

Result:

    No deployment required.

The deployment exits successfully with exit code:

    0

This behavior makes repeated deployment of the same ProfMig package safe.

---

## 10. Upgrade

When the package version is newer than the installed version, ProfMig performs
an upgrade.

Example:

    Installed: 0.2.0
    Package:   0.3.0

The deployment process:

1. validates the new package
2. creates a staging installation
3. validates the staged package
4. moves the current installation to a rollback location
5. activates the new installation
6. copies persistent data into the new installation
7. validates the new installation
8. commits the deployment
9. removes the rollback installation

The following data is preserved:

- Logs
- Reports
- Backup

---

## 11. Downgrade Protection

ProfMig blocks installation of an older version by default.

Example:

    Installed: 0.3.0
    Package:   0.2.0

The deployment stops with exit code:

    4

This prevents an RMM job or administrator from accidentally replacing a newer
ProfMig installation with an older package.

When a downgrade is intentionally required, it can be explicitly enabled:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Deploy-ProfMig.ps1 `
        -AllowDowngrade

An alternate installation path can also be supplied:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Deploy-ProfMig.ps1 `
        -InstallPath 'D:\Applications\ProfMig' `
        -AllowDowngrade

Persistent runtime data is also preserved during an explicitly allowed
downgrade.

---

## 12. Transactional Deployment and Rollback

ProfMig uses temporary staging and rollback directories during deployment.

Conceptually:

    ProfMig
    ProfMig.deploy-<id>
    ProfMig.rollback-<id>

The new package is first copied into a staging directory.

The staging installation is validated before the existing installation is
modified.

During an upgrade, the existing installation is moved to a rollback directory.
The staged installation is then activated.

Persistent data is copied from the rollback installation into the new
installation.

The data is copied rather than moved so that the rollback copy remains complete
until final deployment validation succeeds.

Only after the new installation has passed final validation is the deployment
considered committed.

If deployment fails before that point, ProfMig attempts to restore the previous
installation automatically.

Failure to delete a rollback directory after a successful deployment does not
invalidate the new installation. A warning is generated instead.

Abandoned staging directories are cleaned up where possible.

---

## 13. Reinstall After Normal Uninstall

A normal ProfMig uninstall removes the application but preserves:

    Logs
    Reports
    Backup

This leaves a preserved-data-only ProfMig directory.

Deploy-ProfMig.ps1 recognizes this state.

A later deployment to the same location is treated as:

    clean reinstall with preserved runtime data

The existing persistent directories are preserved while the ProfMig
application is restored.

A directory containing unrelated files or directories is not treated as a
ProfMig preserved-data directory.

This prevents ProfMig from replacing arbitrary directory contents.

---

## 14. Starting ProfMig

### Interactive mode

The normal interactive interface can be started with:

    Start-ProfMig.bat

The deployed runtime displays the ProfMig menu and allows the administrator to
select:

- source profile
- destination profile
- applications
- migration configuration
- migration start
- exit

### Version information

Version information can be requested directly from the PowerShell entry point:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\src\ProfMig.ps1 `
        -Version

### Command-line and silent operation

Automated migration can use the command-line parameters implemented by ProfMig.

For example, ProfMig can be invoked directly through:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\src\ProfMig.ps1 `
        -Silent `
        <migration parameters>

The exact migration parameters depend on the required source, destination and
migration configuration.

For unattended execution, the PowerShell entry point should be used directly
instead of Start-ProfMig.bat.

---

## 15. Deployment Exit Codes

Deploy-ProfMig.ps1 uses the following process exit codes:

| Exit code | Meaning |
| ---: | --- |
| 0 | Success |
| 1 | General deployment failure |
| 2 | Administrator privileges required |
| 3 | Invalid deployment package |
| 4 | Downgrade blocked |

These exit codes can be evaluated by RMM or software-distribution systems.

Example:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Deploy-ProfMig.ps1

    exit /b %ERRORLEVEL%

---

## 16. Normal Uninstall

ProfMig can be removed with:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Uninstall-ProfMig.ps1

By default the ProfMig application is removed while persistent runtime data is
preserved.

Preserved directories:

    Logs
    Reports
    Backup

This is the recommended uninstall mode when migration reports, logs or backup
information may still be required.

An alternate installation location can be supplied:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Uninstall-ProfMig.ps1 `
        -InstallPath 'D:\Applications\ProfMig'

---

## 17. Complete Uninstall

To remove both the ProfMig application and its persistent runtime data:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Uninstall-ProfMig.ps1 `
        -RemoveData

This removes:

- application files
- build metadata
- Logs
- Reports
- Backup
- the installation directory when empty

Use -RemoveData only when the persistent ProfMig data is no longer required.

---

## 18. Uninstall Safety

Before deleting application files, Uninstall-ProfMig.ps1 validates that the
target is a ProfMig installation.

Validation includes:

- ProfMig.Build.psd1 exists
- src\ProfMig.ps1 exists
- build metadata identifies the application as ProfMig

An unrelated directory is rejected rather than deleted.

A missing installation directory is treated as an already-uninstalled state and
returns success.

This behavior is useful for repeatable RMM uninstall jobs.

---

## 19. Uninstall Exit Codes

Uninstall-ProfMig.ps1 uses the following process exit codes:

| Exit code | Meaning |
| ---: | --- |
| 0 | Success or nothing installed |
| 1 | General uninstall failure |
| 2 | Administrator privileges required |
| 3 | Invalid ProfMig installation |

---

## 20. RMM and Software Distribution

ProfMig deployment and uninstall scripts do not require interactive input.

This allows them to be executed by:

- RMM platforms
- software-distribution systems
- administrative PowerShell sessions
- deployment scripts

Example deployment:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Deploy-ProfMig.ps1

Example deployment to a custom location:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File .\Deploy-ProfMig.ps1 `
        -InstallPath 'C:\Tools\ProfMig'

Example normal uninstall:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File 'C:\Program Files\ProfMig\Uninstall-ProfMig.ps1'

Example complete uninstall:

    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File 'C:\Program Files\ProfMig\Uninstall-ProfMig.ps1' `
        -RemoveData

Management platforms should evaluate the documented process exit codes to
determine the result.

---

## 21. Validation and Testing

Sprint 5.5 includes automated validation of the deployment lifecycle.

### Packaging validation

Test-ProfMigPackaging.ps1 validates:

- runtime package structure
- deployment script inclusion
- uninstall script inclusion
- deployment script integrity
- uninstall script integrity
- build metadata
- runtime modules
- application definitions
- migration profiles
- exclusion of development content
- absence of existing runtime output

### Deployment validation

Test-ProfMigDeployment.ps1 validates:

- clean installation
- creation of persistent directories
- same-version deployment
- upgrade
- preservation of logs
- preservation of reports
- preservation of backup data
- downgrade blocking
- explicitly allowed downgrade
- invalid package handling
- deployment cleanup
- deployed Start-ProfMig.bat
- deployed version command
- deployed silent-mode behavior

### Uninstall validation

Test-ProfMigUninstall.ps1 validates:

- clean deployment before uninstall
- normal uninstall
- removal of application files
- preservation of persistent data
- reinstall after normal uninstall
- restoration of the ProfMig runtime
- retention of persistent data during reinstall
- complete uninstall
- removal of the installation directory
- protection of unrelated directories
- idempotent handling of a missing installation

### Command-line regression validation

Test-ProfMigCommandLine.ps1 validates the existing ProfMig command-line and
silent-mode behavior after the deployment changes.

### Manual validation

The following behavior has also been manually validated:

- deployed interactive startup
- normal exit from the interactive ProfMig menu
- non-administrator deployment rejection
- administrator-required exit code 2
- no partial installation after non-administrator rejection

---

## 22. Sprint 5.5 Acceptance Criteria

The Deployment and Update Strategy was designed against the following
acceptance criteria:

| ID | Requirement |
| --- | --- |
| AC-01 | Release package contains all required runtime files and migration profiles |
| AC-02 | Deployment does not require Git or a development repository |
| AC-03 | Default deployment path is C:\Program Files\ProfMig |
| AC-04 | Alternative installation paths are supported |
| AC-05 | Administrator privileges are validated before deployment |
| AC-06 | Package is validated before system changes |
| AC-07 | Installed version is determined using ProfMig.Build.psd1 |
| AC-08 | Clean installation is supported |
| AC-09 | Existing installations are detected |
| AC-10 | Older installations can be upgraded |
| AC-11 | Downgrades are blocked by default |
| AC-12 | Failed deployment protects the previous working installation |
| AC-13 | Deployed ProfMig supports -Version |
| AC-14 | Interactive mode works after deployment |
| AC-15 | CLI and silent operation work after deployment |
| AC-16 | Deployment returns useful process exit codes |
| AC-17 | Uninstall removes ProfMig application files |
| AC-18 | Uninstall preserves logs and reports by default |
| AC-19 | Deployment and uninstall are suitable for unattended/RMM execution |
| AC-20 | Deployment lifecycle is covered by automated and manual validation |

---

## 23. Out of Scope

The following items are intentionally outside Sprint 5.5:

- MSI installer
- MSIX installer
- Windows service
- automatic internet-based updates
- endpoint checks against GitHub
- code signing
- central ProfMig management server
- graphical installer
- vendor-specific RMM integration
- vendor-specific Microsoft Intune integration
- vendor-specific PDQ integration
- vendor-specific N-able integration

These capabilities can be evaluated in a later milestone if required.

---

## 24. Operational Summary

The recommended ProfMig lifecycle is:

    Build package
        |
        v
    Distribute package
        |
        v
    Deploy-ProfMig.ps1
        |
        v
    Run ProfMig
        |
        +--> Interactive
        +--> CLI
        +--> Silent
        |
        v
    Upgrade when required
        |
        v
    Uninstall-ProfMig.ps1
        |
        +--> Preserve runtime data
        |
        or
        |
        +--> -RemoveData for complete removal

This provides ProfMig with a repeatable deployment lifecycle suitable for local
administration and centralized software deployment without requiring access to
the development repository.