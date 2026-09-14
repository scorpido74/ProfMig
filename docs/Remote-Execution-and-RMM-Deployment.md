ProfMig Remote Execution and RMM Deployment

Purpose

This document defines the requirements and validated implementation for
executing ProfMig through Remote Monitoring and Management (RMM) platforms
and other remote management systems.

ProfMig remains vendor-neutral. Remote management products interact with
ProfMig through its deployment scripts, generic remote execution wrapper,
command-line interface, configuration files, process exit codes, logs and
migration reports.

Vendor-specific integration logic must not be added to the ProfMig core.


Remote execution model

Deployment and migration are intentionally separate remote actions.

The generic deployment flow is:

Remote management platform
        |
        v
Deploy ProfMig runtime
        |
        v
Deploy-ProfMig.ps1
        |
        v
Installed ProfMig runtime


The generic migration flow is:

Remote management platform
        |
        v
Invoke-ProfMigRemote.ps1
        |
        v
Resolve installed ProfMig runtime
        |
        v
Start 64-bit Windows PowerShell
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
Return ProfMig process exit code unchanged
        |
        v
Remote management platform interprets result


Separating deployment from migration prevents the remote execution wrapper
from duplicating installation, upgrade or version-management functionality.

Remote execution uses the same validation, migration, security, reporting
and verification components as local execution.


Generic remote execution wrapper

Sprint 5.6 provides the vendor-neutral example:

examples\remote-deployment\Invoke-ProfMigRemote.ps1

The wrapper is intentionally thin.

Its responsibilities are limited to:

resolving the installed ProfMig runtime

ensuring execution through 64-bit Windows PowerShell

providing persistent log and report locations

forwarding migration parameters to ProfMig.ps1

returning the ProfMig migration exit code unchanged


The wrapper does not:

install or upgrade ProfMig

contain migration logic

translate ProfMig migration exit codes

bypass ProfMig validation

contain vendor-specific APIs or paths

contain credentials or tenant information


Installation lifecycle remains the responsibility of Deploy-ProfMig.ps1.

Migration lifecycle remains the responsibility of ProfMig.ps1.


Supported execution contexts

Sprint 5.6 validates ProfMig in the following execution contexts:

Local Administrator

NT AUTHORITY\SYSTEM

Remote management execution context


Interactive user execution is not required for unattended migration.

ProfMig does not rely on the current user's USERPROFILE when identifying
the source or destination migration profile.

This is important during SYSTEM execution because USERPROFILE may resolve
to:

C:\Windows\System32\config\systemprofile


Source and destination profiles are therefore supplied explicitly using
SIDs or profile paths and resolved through the ProfMig profile inventory.


PowerShell architecture

Remote unattended execution requires:

64-bit Windows

Windows PowerShell 5.1 or newer

64-bit PowerShell execution


The ProfMig core validates its execution environment and rejects unsupported
32-bit execution rather than continuing in an ambiguous environment.

Remote management agents may themselves execute scripts through a 32-bit
process.

The generic remote wrapper handles this condition outside the ProfMig core.

On 64-bit Windows, when the wrapper is running as a 32-bit process, it uses:

C:\Windows\Sysnative\WindowsPowerShell\v1.0\powershell.exe


This allows a 32-bit remote management agent to start the native 64-bit
Windows PowerShell process.

When the wrapper already runs as a 64-bit process, it uses the native
System32 Windows PowerShell executable.

The wrapper also uses ProgramW6432 where available when resolving the
default installation path. This prevents a 32-bit process from incorrectly
resolving the ProfMig installation under Program Files (x86).

The normal installed runtime location is:

C:\Program Files\ProfMig


PowerShell architecture handling remains outside the ProfMig migration core.


Silent execution

Remote migration uses ProfMig silent mode.

Silent mode:

requires no interactive input

does not invoke the ProfMig interactive menu

does not require Read-Host

does not require confirmation through an interactive desktop

supports explicit source and destination SIDs

supports explicit source and destination profile paths

returns a predictable process exit code

creates a migration log

creates a migration report when migration reaches reporting

preserves validation, security, ACL and verification controls


Remote execution uses:

-NoProfile

-NonInteractive

-ExecutionPolicy Bypass


A direct ProfMig example is:

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File "C:\Program Files\ProfMig\src\ProfMig.ps1" `
    -Silent `
    -SourceSid "<source-sid>" `
    -DestinationSid "<destination-sid>"


For generic remote management execution, Invoke-ProfMigRemote.ps1 is
preferred because it also handles PowerShell architecture and persistent
output locations.


Command-line interface

The existing ProfMig command-line interface remains the remote management
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


RMM-specific parameters must not be added to ProfMig.ps1.


Configuration deployment

Remote management tooling may deploy:

the ProfMig runtime package

a ProfMig configuration file

a migration profile

generic deployment or execution wrapper scripts


Configuration files may be supplied using -ConfigPath.

Migration profiles may be supplied using -MigrationProfile.

Absolute configuration paths are recommended for remote execution because
the working directory of the management agent may be unrelated to the
ProfMig installation.

Remote configuration passes the same validation as locally supplied
configuration.

Remote execution never bypasses configuration validation.

Sprint 5.6 validates:

external configuration from a different working directory

missing configuration handling

unsupported configuration schema handling

migration-profile selection


Working directory

ProfMig does not depend on the current PowerShell working directory.

Runtime resources are resolved relative to the ProfMig runtime where
appropriate.

This is required because remote management platforms may start execution
from locations such as:

C:\Windows\System32

temporary management-agent directories

user temporary directories

custom deployment directories


SYSTEM testing confirmed that the working directory may be:

C:\Windows\System32


without preventing ProfMig from locating its runtime resources.

Remote tooling may also stage deployment packages in temporary locations.


Persistent output

Deployment packages or temporary staging directories may be removed after
execution.

Logs and reports must therefore remain available independently of temporary
deployment files.

When the generic remote wrapper is used with an installed ProfMig runtime,
the default persistent locations are:

<InstallPath>\Logs

<InstallPath>\Reports


With the default installation path these become:

C:\Program Files\ProfMig\Logs

C:\Program Files\ProfMig\Reports


Direct ProfMig execution may instead provide alternative persistent
locations through:

-LogPath

-ReportPath


For example:

C:\ProgramData\ProfMig\Logs

C:\ProgramData\ProfMig\Reports


ProgramData locations are deployment recommendations only. They are not
hardcoded RMM-specific locations in the ProfMig core.


Process exit codes

ProfMig provides the following stable migration process exit-code contract:

0   Success

1   SuccessWithWarnings

2   MigrationFailed

3   ConfigurationError

4   ValidationError

5   PermissionError

6   InsufficientStorage

7   VerificationError

8   ApplicationMigrationError

99  UnexpectedError


Remote management software uses the process exit code as the primary
machine-readable execution result.

The generic remote wrapper returns the ProfMig migration exit code unchanged.

Wrapper infrastructure failures that prevent ProfMig from being started
return:

99  UnexpectedError


Console output is not the only mechanism used to determine migration
success or failure.

Deployment-script exit codes belong to the deployment lifecycle and must
not be confused with the ProfMig migration exit-code contract.


Logging

Remote execution creates a local ProfMig log.

The log location can be supplied through -LogPath.

The generic remote wrapper provides a persistent log location automatically
when no alternative is supplied through the deployment design.

Logging continues to use the existing ProfMig logging framework.

Remote execution does not introduce a separate RMM-specific logging
implementation.

Existing sensitive-data protection remains active.


Reporting

Remote execution uses the existing ProfMig reporting framework.

The report location can be supplied through -ReportPath.

The generic remote wrapper provides a persistent report location.

Reports remain independent of the remote management platform.

RMM integrations may collect or upload ProfMig reports after execution,
but that behaviour belongs in deployment or vendor integration scripts.

Sprint 5.6 regression testing generates reports through the real
ProfMig.Reporting module and validates that remote tooling can locate and
interpret the generated report.


Remote result interpretation

Remote management tooling interprets ProfMig execution using three layers:

1. Process exit code

   Immediate machine-readable execution status.

2. ProfMig migration report

   Detailed migration result including source, destination, timing,
   statistics, verification status and overall migration status.

3. ProfMig log

   Diagnostic information for troubleshooting and support.


The migration report exposes remotely interpretable information including:

Source

Destination

Started

Completed

Duration

Files selected

Files copied

Files skipped

Files failed

Verification information

Overall result

Copy Engine status


Sprint 5.6 testing confirms that the existing exit-code, report and log
combination provides sufficient remote result interpretation.

A separate JSON result file is therefore not required by Sprint 5.6.

Structured output may be considered in a future sprint only if a validated
integration requirement demonstrates that the existing result contract is
insufficient.


Network availability

ProfMig core migration does not depend on continuous connectivity to the
remote management platform.

Once the runtime and required configuration are available locally,
migration can continue independently of the RMM connection.

Vendor-specific download, upload, callback and connectivity handling belongs
outside the ProfMig core.


Reboot behaviour

ProfMig does not initiate an uncontrolled reboot during remote migration.

If a future migration operation requires a reboot, that requirement must
be returned to the calling deployment layer in a predictable manner.

Reboot orchestration remains the responsibility of the deployment or
management platform.


Cleanup

Remote management tooling may remove temporary deployment or staging files
after ProfMig has completed.

Cleanup must not remove required persistent logs or migration reports.

The generic remote result regression test creates isolated temporary test
artifacts and verifies their cleanup after testing.

ProfMig core contains no vendor-specific cleanup logic.


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


Generic deployment and execution examples may be provided separately from
the ProfMig core.

Vendor-specific examples, if added in the future, must remain isolated from
the ProfMig runtime.


Security requirements

Remote execution preserves all existing ProfMig security controls.

Remote execution does not:

bypass profile validation

bypass privilege validation

bypass storage validation

disable ACL handling

disable migration verification

expose credentials

expose sensitive information in logs or reports


Execution as SYSTEM does not imply that validation may be skipped.


Sprint 5.6 validation

Sprint 5.6 validates:

silent non-interactive execution

Administrator execution

SYSTEM execution

64-bit PowerShell execution

32-bit remote wrapper behaviour through Sysnative

native Program Files resolution from a 32-bit process

execution from a non-project working directory

external configuration-file deployment

migration-profile deployment

process exit-code propagation and interpretation

persistent logging

persistent report generation

remote result interpretation

temporary test-artifact cleanup

generic vendor-neutral remote execution

existing security and validation controls


The Sprint 5.6 validation suite includes:

tests\Test-ProfMigRemoteExecution.ps1

tests\Test-ProfMigCommandLine.ps1

tests\Test-ProfMigRemoteConfiguration.ps1

tests\Test-ProfMigRemoteExitCodes.ps1

tests\Test-ProfMigRemoteResults.ps1

tests\Test-ProfMigRemoteWrapper.ps1


Existing packaging, deployment, versioning, uninstall and Milestone 3
regression tests remain applicable.


Acceptance criteria

Remote execution is accepted when:

ProfMig runs without interactive input

ProfMig runs through a generic remote execution context

Administrator execution works

SYSTEM execution works

64-bit PowerShell requirements are enforced

32-bit remote execution can reach 64-bit ProfMig through the generic wrapper

configuration can be supplied remotely

migration profiles can be supplied remotely

process exit codes can be interpreted externally

the wrapper preserves ProfMig migration exit codes

logs are generated

migration reports are generated

remote tooling can interpret the generated migration report

persistent output is separated from temporary staging where required

existing security and validation controls remain active

the ProfMig core contains no RMM-vendor-specific dependencies


Definition of Done

Sprint 5.6 is complete when ProfMig can be deployed, executed, monitored
and interpreted through generic remote management tooling without
interactive input or vendor-specific dependencies, while preserving all
existing validation, security, logging, reporting and verification
controls.

Deployment, migration and remote result interpretation must remain
separable so that different management platforms can integrate ProfMig
without requiring changes to the ProfMig core.
