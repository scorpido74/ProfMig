# ProfMig Packaging and Application Structure

## Overview

ProfMig uses a clear separation between the development repository and the runtime package.

The development repository contains source code, tests, documentation, build tooling and GitHub automation.

The runtime package contains only the components required to execute ProfMig.

This structure provides a predictable deployment model for local execution and future deployment through Microsoft Intune, RMM platforms and release packages.

## Development Repository

The ProfMig development repository contains the following main components:

```text
ProfMig\
├── .github\              GitHub workflows
├── build\                Packaging and build tooling
├── docs\                 Technical documentation
├── src\                  ProfMig runtime source
├── tests\                Automated and manual tests
├── Logs\                 Development runtime logs
├── Reports\              Development runtime reports
├── Start-ProfMig.bat     Interactive launcher
└── supporting repository files
```

Development-only content is not required on systems where ProfMig is deployed.

## Runtime Package

The runtime package is generated under:

```text
dist\ProfMig\
```

The package has the following structure:

```text
ProfMig\
├── Start-ProfMig.bat
├── LICENSE
├── Logs\
├── Reports\
└── src\
    ├── Config.psd1
    ├── ProfMig.ps1
    ├── Applications\
    └── Modules\
```

`src\ProfMig.ps1` is the central application entry point.

`Start-ProfMig.bat` provides the current interactive launcher.

## Portable Runtime

ProfMig resolves runtime paths relative to its own application location.

The runtime does not require installation in a fixed directory such as:

```text
C:\install\ProfMig
```

The generated package can therefore be copied to another directory and executed from that location.

During Sprint 5.1 validation, the generated package was copied to:

```text
C:\install\ProfMig-Package-Test
```

ProfMig successfully started and completed a normal interactive session from that location.

Runtime logging was also confirmed to use the package-local `Logs` directory.

## Package Generation

The runtime package is generated with:

```powershell
.\build\New-ProfMigPackage.ps1
```

By default the package is created at:

```text
dist\ProfMig
```

A different output location can be supplied with the `OutputPath` parameter.

Example:

```powershell
.\build\New-ProfMigPackage.ps1 -OutputPath 'C:\Temp\ProfMig'
```

The packaging process removes an existing package at the target location before generating a new package.

This prevents files from previous builds from remaining in a new release.

## Required Runtime Components

The packaging process validates the presence of the following source components before building:

- `Start-ProfMig.bat`
- `LICENSE`
- `src\ProfMig.ps1`
- `src\Config.psd1`
- `src\Modules`
- `src\Applications`

Package generation fails when a required component is missing.

## Runtime Output

The package contains empty directories for:

```text
Logs\
Reports\
```

Existing development logs and reports are never copied into the package.

Runtime-generated data therefore belongs to the deployed ProfMig instance rather than to the development repository.

## Development-Only Components

The following components must not be included in a runtime package:

- `.git`
- `.github`
- `tests`
- `docs`
- `Backup`
- `TestData`
- Existing logs
- Existing reports

The packaging script performs validation to detect development-only components in the generated package.

## Git Repository Behaviour

Generated packages are stored under:

```text
dist\
```

The `dist` directory is excluded through `.gitignore`.

Generated runtime packages and future ZIP release artifacts must not be committed as source code.

## Deployment Architecture

The packaging structure establishes the following deployment model:

```text
Development Repository
        |
        v
New-ProfMigPackage.ps1
        |
        v
   Runtime Package
        |
        +------------------+
        |                  |
        v                  v
Interactive execution   Automated deployment
                           |
                    +------+------+
                    |             |
                    v             v
                  Intune         RMM
```

All deployment methods use the same ProfMig runtime source and migration engine.

Deployment tooling must not create separate versions of the ProfMig application.

## Security Considerations

The current interactive BAT launcher uses PowerShell with:

```text
-ExecutionPolicy Bypass
```

This behaviour is retained during Sprint 5.1 for compatibility with the existing application.

Execution policy, Authenticode signatures, certificate trust and secure execution requirements are addressed separately by the M5 code-signing and execution-security work.

The runtime package must not contain credentials, private keys, passwords or other deployment secrets.

## Validation

Sprint 5.1 packaging validation confirmed:

- Clean package generation succeeds.
- Repeated package generation succeeds.
- Previous package contents are removed before rebuilding.
- All required runtime modules are included.
- Application definitions are included.
- `Logs` and `Reports` start empty.
- Development-only directories are excluded.
- The package can execute outside the development repository.
- ProfMig writes runtime logs relative to the deployed package.
- No fixed development installation path is required.

## Future M5 Integration

This runtime package forms the basis for subsequent M5 work:

- Command-line and silent execution.
- Reusable migration configuration.
- Versioning and build information.
- Microsoft Intune deployment.
- RMM deployment.
- Code signing and execution security.
- Deployment and automation validation.

These deployment methods should consume the same runtime package rather than maintaining independent copies of ProfMig.