ProfMig Remote Execution and RMM Deployment

Purpose

This document defines the requirements for executing ProfMig through
Remote Monitoring and Management (RMM) platforms and other remote
management systems.

ProfMig remains vendor-neutral. Remote management products interact with
ProfMig through its command-line interface, configuration files, process
exit codes, logs and migration reports.

Vendor-specific integration logic must not be added to the ProfMig core.

Remote execution model

The generic remote execution flow is:

Remote management platform
        |
        v
Deploy ProfMig runtime
        |
        v
Start 64-bit PowerShell
        |
        v
ProfMig.ps1 -Silent
        |
        v
Load configuration
        |
        v
Validate environment and profiles
        |
        v
Execute migration
        |
        v
Verify migration
        |
        v
Generate report and log
        |
        v
Return process exit code
        |
        v
Remote management platform interprets result

Remote execution must use the same validation, migration, security,
reporting and verification components as local execution.

Supported execution contexts

Sprint 5.6 validates ProfMig in the following execution contexts:

Local Administrator

NT AUTHORITY\SYSTEM

Remote management execution context

Interactive user execution is not required for unattended migration.

ProfMig must not rely on the current user's USERPROFILE when identifying
the source or destination migration profile.

Source and destination profiles must be resolved explicitly through the
ProfMig profile inventory.

PowerShell architecture

Remote unattended execution requires 64-bit Windows PowerShell.

Remote management platforms may launch scripts through a 32-bit process.
Deployment tooling must therefore ensure that ProfMig is executed using
64-bit PowerShell.

ProfMig must detect unsupported execution environments and fail
predictably rather than continue with an ambiguous execution context.

Vendor-specific PowerShell redirection behaviour must remain outside the
ProfMig core.

Silent execution

Remote migration must use ProfMig silent mode.

Silent mode must:

require no interactive input

never call Read-Host

never display a confirmation prompt that requires user interaction

complete without an interactive desktop

return a predictable process exit code

create a migration log

create a migration report when migration reaches reporting

preserve all validation and security controls

Example:

powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File ".\src\ProfMig.ps1" `
    -Silent `
    -SourceSid "<source-sid>" `
    -DestinationSid "<destination-sid>"

Profile paths may be used instead of SIDs where appropriate.

Command-line interface

The existing ProfMig command-line interface is the remote management
interface.

Relevant parameters include:

-Silent

-SourceSid

-DestinationSid

-SourceProfilePath

-DestinationProfilePath

-SkipApplications

-ConfigPath

-MigrationProfile

-LogPath

-ReportPath

RMM-specific parameters must not be added to ProfMig.

Configuration deployment

Remote management tooling may deploy:

the ProfMig runtime package

a ProfMig configuration file

a migration profile

deployment wrapper scripts

Configuration files may be supplied using -ConfigPath.

Migration profiles may be supplied using -MigrationProfile.

Remote configuration must pass the same validation as locally supplied
configuration.

Remote execution must never bypass configuration validation.

Working directory

ProfMig must not depend on the current PowerShell working directory.

Runtime resources must be resolved relative to the ProfMig runtime where
appropriate.

The following deployment locations are examples and must not be
hardcoded:

C:\Windows\Temp\ProfMig

C:\ProgramData\<ManagementTool>\Temp\ProfMig

user temporary directories

custom deployment directories

Remote tooling may execute ProfMig from temporary locations.

Persistent output

Deployment packages may be removed after execution.

Logs and reports should therefore be capable of being written outside
the temporary deployment directory using:

-LogPath

-ReportPath

A generic remote deployment should normally use a persistent location
such as:

C:\ProgramData\ProfMig\Logs
C:\ProgramData\ProfMig\Reports

These locations are deployment recommendations and must not become
hardcoded RMM-specific paths in the ProfMig core.

Process exit codes

ProfMig already provides stable process exit codes.

Exit code

Result

0

Success

1

SuccessWithWarnings

2

MigrationFailed

3

ConfigurationError

4

ValidationError

5

PermissionError

6

InsufficientStorage

7

VerificationError

8

ApplicationMigrationError

99

UnexpectedError

Remote management software must use the process exit code as the primary
machine-readable execution result.

Console output must not be the only mechanism used to determine migration
success or failure.

Logging

Remote execution must create a local ProfMig log.

The log location may be supplied through -LogPath.

Logging must continue to use the existing ProfMig logging framework.

Remote execution must not introduce a separate RMM-specific logging
implementation.

Sensitive-data protection already provided by ProfMig must remain active.

Reporting

Remote execution must use the existing ProfMig reporting framework.

The report location may be supplied through -ReportPath.

Reports must remain independent of the remote management platform.

RMM integrations may collect or upload ProfMig reports after execution,
but that behaviour belongs in deployment or vendor integration scripts.

Remote result interpretation

Remote management tooling should interpret ProfMig execution using:

process exit code

ProfMig migration report

ProfMig log

The process exit code provides the immediate machine-readable result.

Reports provide migration details.

Logs provide diagnostic information.

A future structured result file may be added if remote management testing
shows that exit codes and existing structured reporting are insufficient.

Sprint 5.6 must not duplicate existing reporting functionality without a
validated requirement.

Network availability

ProfMig core migration must not depend on continuous connectivity to the
remote management platform.

Once the runtime and required configuration are available locally,
migration should continue independently of the RMM connection where
possible.

Vendor-specific download, upload and connectivity handling belongs
outside the ProfMig core.

Reboot behaviour

ProfMig must not initiate an uncontrolled reboot during remote migration.

If a future migration operation requires a reboot, that requirement must
be returned to the calling deployment layer in a predictable manner.

Reboot orchestration remains the responsibility of the deployment or
management platform.

Cleanup

Remote management tooling may remove temporary deployment files after
ProfMig has completed.

Cleanup must not remove required persistent logs or migration reports.

ProfMig core must not contain vendor-specific cleanup logic.

Vendor neutrality

The following are prohibited inside the ProfMig core:

RMM vendor names or APIs

vendor-specific registry locations

vendor-specific temporary paths

embedded credentials

API tokens

tenant identifiers

vendor-specific upload logic

vendor-specific result formats

Generic deployment examples may be provided separately.

Vendor-specific examples must remain isolated from the ProfMig runtime.

Security requirements

Remote execution must preserve all existing ProfMig security controls.

Remote execution must not:

bypass profile validation

bypass privilege validation

bypass storage validation

disable ACL handling

disable migration verification

expose credentials

expose sensitive information in logs or reports

Execution as SYSTEM does not imply that validation may be skipped.

Sprint 5.6 validation targets

Sprint 5.6 must validate:

silent execution

Administrator execution

SYSTEM execution

64-bit PowerShell execution

behaviour under 32-bit PowerShell

execution from a non-project working directory

execution from a temporary deployment directory

configuration-file deployment

migration-profile deployment

process exit-code interpretation

persistent logging

persistent report generation

remote result interpretation

cleanup behaviour

operation without continuous RMM connectivity

Acceptance criteria

Remote execution is accepted when:

ProfMig runs without interactive input

ProfMig runs through a generic remote execution context

Administrator execution works

SYSTEM execution works

64-bit PowerShell requirements are validated

configuration can be supplied remotely

migration profiles can be supplied remotely

process exit codes can be interpreted externally

logs are generated

migration reports are generated

output can survive removal of the deployment directory

existing security and validation controls remain active

the ProfMig core contains no RMM-vendor-specific dependencies

Definition of Done

Sprint 5.6 is complete when ProfMig can be deployed, executed, monitored
and interpreted through generic remote management tooling without
interactive input or vendor-specific dependencies, while preserving all
existing validation, security, logging, reporting and verification
controls.