# ProfMig Milestone 5 Validation Matrix

## Purpose

This document defines the validation coverage and acceptance status for **Milestone 5 – Deployment & Automation**.

Milestone 5 validation verifies that ProfMig can be packaged, deployed, executed, migrated and interpreted reliably outside the development repository and through automated deployment mechanisms.

Validation consists of:

* automated regression validation;
* end-to-end deployment and migration validation;
* environment-dependent platform validation.

---

# Automated Validation

The central Milestone 5 automated validation runner is:

`tests\M5\Invoke-M5Tests.ps1`

The runner executes the Milestone 5 test suites together with the Milestone 3 automated regression suite.

## Final automated validation

Final E2E-08 regression result:

* M5 test suites: **13 passed, 0 failed**
* M3 regression tests: **47 passed, 0 failed**
* `git diff --check`: **PASS**
* Overall M5 automated validation: **PASS**

The following M5 suites completed successfully:

| Test suite                   | Result |
| ---------------------------- | ------ |
| Packaging                    | PASS   |
| Versioning                   | PASS   |
| Command-Line and Silent Mode | PASS   |
| Deployment                   | PASS   |
| Uninstall                    | PASS   |
| Intune Detection             | PASS   |
| Remote Configuration         | PASS   |
| Remote Execution             | PASS   |
| Remote Exit Codes            | PASS   |
| Remote Results               | PASS   |
| Remote Wrapper               | PASS   |
| Code Signing and Integrity   | PASS   |
| Milestone 3 Regression       | PASS   |

Additional regression coverage was introduced during E2E validation for defects identified in:

* launcher command-line argument handling;
* launcher exit-code propagation;
* configured default migration profile resolution;
* explicit migration profile precedence;
* Intune incomplete-install detection.

All affected regression suites passed after the corrections.

Relevant final regression results include:

* Deployment validation: **33 passed, 0 failed**
* Remote configuration validation: **5 passed, 0 failed**
* Intune detection validation: **6 passed, 0 failed**
* Remote wrapper validation: **7 passed, 0 failed**
* Code signing and integrity validation: **6 passed, 0 failed**
* M3 automated regression: **47 passed, 0 failed**

---

# Validation Matrix

| Area                | Automated coverage                                                                      | Status | E2E validation           |
| ------------------- | --------------------------------------------------------------------------------------- | ------ | ------------------------ |
| Runtime packaging   | Package creation, required files, modules, definitions, profiles and deployment tooling | PASS   | E2E-01                   |
| Versioning          | Version format, CLI version and package metadata                                        | PASS   | E2E-01 / E2E-07          |
| CLI / silent mode   | Parameter validation and predictable exit codes                                         | PASS   | E2E-01 / E2E-02          |
| Configuration       | External configuration, schema validation, default profile and CLI precedence           | PASS   | E2E-03                   |
| Deployment          | Clean/same-version deployment, persistent data and deployment structure                 | PASS   | E2E-01 / E2E-06          |
| Uninstall           | Runtime removal and persistent-data preservation                                        | PASS   | E2E-06                   |
| Intune detection    | Missing, valid, invalid and incomplete installations                                    | PASS   | E2E-06                   |
| Remote execution    | Architecture, environment and execution context                                         | PASS   | E2E-04 / E2E-05          |
| Remote exit codes   | Warning, configuration, validation and wrapper failures                                 | PASS   | E2E-02 / E2E-04 / E2E-05 |
| Remote results      | Logging, reports and result interpretation                                              | PASS   | E2E-04 / E2E-05          |
| Remote wrapper      | Working-directory independence and 32/64-bit execution                                  | PASS   | E2E-05                   |
| Code signing        | Authenticode signing and tamper detection                                               | PASS   | E2E-07                   |
| Package integrity   | SHA-256 release manifest and tamper detection                                           | PASS   | E2E-07                   |
| M3 regression       | Core migration reliability and security regression                                      | PASS   | E2E-08                   |
| Logging / reporting | Generation and persistence                                                              | PASS   | E2E-02 / E2E-04 / E2E-05 |
| Security            | ACL handling, secret protection, signing and integrity                                  | PASS   | E2E-04 / E2E-07          |

---

# End-to-End Validation

## E2E-01 – Standalone Runtime Package

**Status: PASS**

**Validated:** 2026-09-14

### Objective

Validate a generated ProfMig runtime package independently of the source repository.

### Validation performed

Confirmed that:

* the standalone runtime package was created successfully;
* required runtime files and directories were present;
* all required PowerShell modules were included;
* application definitions and migration profiles were included;
* deployment and uninstall functionality was included;
* `src\ProfMig.ps1` executed independently of the repository;
* version information could be retrieved;
* `Start-ProfMig.bat` executed the standalone runtime;
* command-line arguments were forwarded correctly;
* ProfMig exit codes were preserved;
* unattended execution did not pause;
* no dependency on `C:\install\ProfMig` existed in the generated runtime.

### Results

Runtime:

* Version: `0.2.0`
* Build: `Development`
* `-Version` exit code: `0`

Invalid silent invocation:

* expected configuration failure;
* exit code: `3`.

### Defect

E2E-01 identified DEF-01 in `Start-ProfMig.bat`.

The launcher did not correctly support unattended command-line execution.

The defect was corrected and protected by deployment regression coverage.

### Conclusion

**PASS**

---

## E2E-02 – Successful Silent Migration

**Status: PASS**

**Validated:** 2026-09-14

### Objective

Perform a real silent migration using the standalone packaged runtime.

### Environment

Source:

`C:\Users\ProfMigTestUser`

Destination:

`C:\Users\ProfMigSilentTest`

Migration profile:

`Minimal`

Components:

* Desktop
* Documents

Application migration:

* Disabled

Verification:

* Standard
* SHA256

### Results

Two unique E2E marker files were migrated.

Desktop:

* destination created: PASS
* source preserved: PASS
* SHA-256 match: PASS

Documents:

* destination created: PASS
* source preserved: PASS
* SHA-256 match: PASS

Migration:

* files copied: `2`
* failed: `0`
* verified: `2`
* verification failures: `0`
* bytes copied: `242`

Result:

`Success with warnings`

Exit code:

`1`

Warnings resulted from existing destination data and Windows compatibility reparse points in the reused test profiles.

### Conclusion

**PASS**

---

## E2E-03 – External Configuration and Default Profile

**Status: PASS**

**Validated:** 2026-09-14

### Objective

Validate external configuration, configuration validation, default migration profile selection and explicit CLI precedence.

### Validation

Confirmed:

* valid external configuration accepted;
* missing configuration rejected with exit code `3`;
* unsupported schema `99.0` rejected with exit code `3`;
* unsupported verification configuration rejected;
* configured `DefaultProfile` used when no CLI profile is supplied;
* explicit `-MigrationProfile` has precedence.

### Defect

E2E-03 identified DEF-02.

`Migration.DefaultProfile` was defined but not used during runtime migration-profile resolution.

Resolution precedence is now:

1. explicit `-MigrationProfile`;
2. configured `Migration.DefaultProfile`;
3. standard configuration fallback.

Regression:

* Remote Configuration: **5 passed, 0 failed**

### E2E result

After rebuilding the standalone runtime:

* `Minimal` selected automatically;
* Desktop and Documents selected;
* application migration disabled;
* both marker files copied;
* both marker files verified;
* failed files: `0`;
* verification failures: `0`.

### Conclusion

**PASS**

---

## E2E-04 – LocalSystem Execution

**Status: PASS**

**Validated:** 2026-09-14

### Objective

Execute a real ProfMig migration as:

`NT AUTHORITY\SYSTEM`

### Environment validation

Confirmed:

* Windows PowerShell `5.1.26100.9444`;
* 64-bit OS;
* 64-bit PowerShell;
* working directory `C:\Windows\system32`;
* USERPROFILE `C:\Windows\system32\config\systemprofile`;
* standalone runtime accessible.

### Migration

A Windows Scheduled Task executed ProfMig under LocalSystem.

Two unique marker files were migrated.

Results:

* files copied: `2`;
* files failed: `0`;
* files verified: `2`;
* verification failures: `0`;
* bytes copied: `124`;
* verification: Standard / SHA256.

Result:

`Success with warnings`

ProfMig exit code:

`1`

Scheduled Task result:

`1`

This validates:

`ProfMig -> Start-ProfMig.bat -> SYSTEM PowerShell -> Scheduled Task`

### Conclusion

**PASS**

---

## E2E-05 – Remote/RMM Execution

**Status: PASS**

**Validated:** 2026-09-14

### Objective

Validate the vendor-neutral remote execution interface introduced in Sprint 5.6.

### Execution chain

`Management caller -> Invoke-ProfMigRemote.ps1 -> native 64-bit PowerShell -> ProfMig -> logs/reports -> exit code`

### Positive migration

Two marker files were migrated through the remote wrapper.

Results:

* files copied: `2`;
* files failed: `0`;
* files verified: `2`;
* verification failures: `0`;
* bytes copied: `124`.

ProfMig returned:

`1`

Remote wrapper returned:

`1`

### Negative validation

Invalid source and destination SIDs produced:

* Category: `ValidationError`
* Reason: `ProfileNotFound`
* ProfMig exit code: `4`
* remote caller exit code: `4`

### Cleanup and persistence

Confirmed after execution:

* runtime preserved;
* logs preserved;
* reports preserved;
* migrated Desktop data preserved;
* migrated Documents data preserved.

Lifecycle and cleanup remain responsibilities of the calling management platform.

### Conclusion

**PASS**

---

## E2E-06 – Intune Deployment Lifecycle

**Status: PASS – LOCAL LIFECYCLE**

**Managed-device validation: DEFERRED**

**Validated:** 2026-09-14

### Objective

Validate ProfMig Win32 packaging, installation, detection and uninstall behaviour required for Microsoft Intune deployment.

### Package creation

The Intune packaging workflow successfully generated:

`ProfMig-0.2.0.intunewin`

Package size:

approximately `0.14 MB`

The package contained:

* ProfMig runtime;
* deployment script;
* uninstall script;
* version metadata;
* generated version-specific Intune detection script.

### Local Intune-equivalent lifecycle

The following lifecycle was validated locally using the exact deployment and detection components intended for Intune:

1. existing ProfMig installation detected;
2. previous installation uninstalled;
3. runtime removed;
4. persistent Logs, Reports and Backup retained;
5. detection after uninstall returned not installed;
6. new package installed successfully;
7. package metadata validated;
8. runtime entry point validated;
9. repeated detection remained stable;
10. installed runtime executed successfully.

Installed runtime:

* Version: `0.2.0`
* Build: `Development`
* `-Version` exit code: `0`

### Defect

E2E-06 identified DEF-03.

The original Intune detection script validated version metadata but did not verify that the ProfMig runtime entry point still existed.

An incomplete installation containing valid metadata could therefore be reported as installed.

### Resolution

Intune detection now requires:

* installation directory;
* `ProfMig.Build.psd1`;
* `src\ProfMig.ps1`;
* product name `ProfMig`;
* exact expected version.

Regression coverage was extended.

Intune detection regression:

* **6 passed**
* **0 failed**

### Incomplete installation E2E test

`src\ProfMig.ps1` was deliberately removed while valid metadata remained.

Result:

* original behaviour: falsely detected;
* corrected behaviour: detection exit code `1`;
* runtime restored;
* healthy detection returned exit code `0`.

DEF-03 result:

**RESOLVED – PASS**

### Managed Intune device validation

Actual Microsoft Intune Win32 assignment and deployment to a managed test device was intentionally deferred.

The generated `.intunewin`, install command, uninstall command and detection script are ready for this platform validation.

This deferred test is an environment-dependent integration validation and does not invalidate the completed local deployment lifecycle or automated Intune detection coverage.

### Conclusion

**PASS – LOCAL DEPLOYMENT LIFECYCLE**

**MANAGED-DEVICE INTEGRATION TEST DEFERRED**

---

## E2E-07 – Signed Release Package

**Status: PASS**

**Validated:** 2026-09-14

### Objective

Validate a complete ProfMig runtime package using Authenticode code signing and SHA-256 release integrity protection.

### Signing certificate

Subject:

`CN=Remco de Kievit - ProfMig Code Signing, O=ProfMig`

Thumbprint:

`1B36B783F024480C175FDB50323C32B082B2BD6A`

Certificate validity:

* valid from 2026-09-14;
* valid through 2028-09-13;
* private key available;
* Code Signing capability available.

### Release build

A fresh runtime was generated at:

`C:\Temp\ProfMig-M5-E2E07\ProfMig`

Results:

* package creation: exit code `0`;
* PowerShell files signed: `23`;
* signing exit code: `0`;
* SHA-256 manifest files: `30`;
* manifest creation exit code: `0`.

The release process used the required order:

`Build -> Authenticode signing -> SHA-256 manifest`

### Clean package validation

Authenticode:

* valid signatures: `23/23`;
* validation exit code: `0`.

SHA-256:

* valid files: `30/30`;
* validation exit code: `0`.

`src\ProfMig.ps1`:

* Authenticode status: `Valid`;
* signer certificate: expected certificate;
* thumbprint: expected thumbprint.

Signed runtime execution:

* ProfMig version: `0.2.0`;
* Build: `Development`;
* exit code: `0`.

### Executable tamper test

`src\ProfMig.ps1` was modified after signing.

Results:

* Authenticode status: `NotSigned`;
* signature validation: rejected;
* signature validation result: `1`;
* SHA-256 validation: rejected;
* hash validation result: `1`.

Result:

**Executable tampering rejected: PASS**

### Non-executable tamper test

`src\Config.psd1` was modified without modifying any signed PowerShell file.

Results:

* Authenticode validation remained `23/23`;
* SHA-256 validation detected `HashMismatch`;
* integrity validation rejected the package.

Result:

**Non-executable tampering rejected: PASS**

### Security model validated

The test confirms two complementary protection layers:

* Authenticode protects executable PowerShell content;
* the SHA-256 release manifest protects the complete release package, including configuration and other non-PowerShell content.

### Conclusion

**PASS**

---

## E2E-08 – Final Regression

**Status: PASS**

**Validated:** 2026-09-14

### Objective

Perform the complete automated regression after all Milestone 5 E2E scenarios and defect corrections.

### Repository validation

`git diff --check`

Result:

`0 – PASS`

### M5 automated validation

`tests\M5\Invoke-M5Tests.ps1`

Results:

| Test                         | Result |
| ---------------------------- | ------ |
| Packaging                    | PASS   |
| Versioning                   | PASS   |
| Command-Line and Silent Mode | PASS   |
| Deployment                   | PASS   |
| Uninstall                    | PASS   |
| Intune Detection             | PASS   |
| Remote Configuration         | PASS   |
| Remote Execution             | PASS   |
| Remote Exit Codes            | PASS   |
| Remote Results               | PASS   |
| Remote Wrapper               | PASS   |
| Code Signing and Integrity   | PASS   |
| Milestone 3 Regression       | PASS   |

Summary:

* Total: `13`
* Passed: `13`
* Failed: `0`

### M3 regression

Results:

* Total: `47`
* Passed: `47`
* Failed: `0`
* Skipped: `0`
* Pending: `0`
* Inconclusive: `0`

### Final result

`M5 AUTOMATED VALIDATION: PASS`

`E2E-08 Final Regression: PASS`

### Conclusion

**PASS**

The complete automated regression remains successful after DEF-01, DEF-02 and DEF-03 and the additional Milestone 5 validation coverage.

---

# Defects Identified During E2E Validation

## DEF-01 – Launcher Argument and Exit-Code Handling

**Status: RESOLVED**

**Identified during:** E2E-01

### Problem

`Start-ProfMig.bat` did not correctly support unattended command-line execution.

### Resolution

The launcher now:

* forwards arguments using `%*`;
* captures the ProfMig exit code;
* returns the exit code to the caller;
* pauses only when launched interactively without arguments.

Regression:

* Deployment: **33 passed, 0 failed**

Validated by:

* E2E-01
* E2E-02
* E2E-04

---

## DEF-02 – Configured Default Migration Profile Ignored

**Status: RESOLVED**

**Identified during:** E2E-03

### Problem

`Migration.DefaultProfile` was ignored when `-MigrationProfile` was omitted.

### Resolution

Migration profile selection now follows:

1. explicit `-MigrationProfile`;
2. configured `Migration.DefaultProfile`;
3. standard configuration fallback.

Regression:

* Remote Configuration: **5 passed, 0 failed**

Validated by:

* E2E-03
* E2E-08

---

## DEF-03 – Intune Detection Accepted Incomplete Installation

**Status: RESOLVED**

**Identified during:** E2E-06

### Problem

The original Intune detection script validated package metadata and version but did not verify that the ProfMig runtime entry point existed.

An incomplete installation could therefore be reported as successfully installed.

### Resolution

Detection now additionally requires:

`src\ProfMig.ps1`

The minimum detection contract is:

* installation directory exists;
* `ProfMig.Build.psd1` exists;
* `src\ProfMig.ps1` exists;
* metadata product name is `ProfMig`;
* installed version equals the expected version.

Regression:

* Intune Detection: **6 passed, 0 failed**

E2E incomplete-install test:

* healthy installation: detection `0`;
* runtime removed: detection `1`;
* runtime restored: detection `0`.

Validated by:

* E2E-06
* E2E-08

---

# Known Validation Observations

## Reused Test Profiles

E2E-02 through E2E-05 reused existing Windows test profiles.

Existing destination files were safely skipped rather than overwritten.

This caused expected:

`Success with warnings`

and exit code:

`1`

Unique marker files were used for each E2E scenario to independently verify newly migrated data.

No marker-file verification failures occurred.

## Exit-Code Contract

Observed deployment and migration results include:

| Exit code | Meaning                            |
| --------: | ---------------------------------- |
|       `0` | Successful execution               |
|       `1` | Successful migration with warnings |
|       `2` | Migration failure                  |
|       `3` | Configuration error                |
|       `4` | Validation error                   |
|       `5` | Permission error                   |
|      `99` | Remote wrapper/runtime failure     |

This contract remained predictable throughout automated and E2E validation.

## Windows Profile Hive State

The two reusable test-profile registry hives remained loaded even without active interactive sessions.

Windows denied manual hive unload.

ProfMig successfully completed user-context, LocalSystem and remote-wrapper migrations despite this condition.

No Milestone 5 defect was attributed to the loaded hive state.

## Reparse Points

Windows compatibility reparse points under Documents were intentionally not traversed.

They were reported as skipped rather than failed.

No verification failure resulted from this behaviour.

## Working-Directory Independence

Validated caller working directories included:

`C:\Windows\system32`

and:

`C:\Windows\Temp`

ProfMig and the remote wrapper correctly resolved runtime resources without depending on the repository or runtime directory being the current working directory.

## Remote Result Persistence

Remote execution preserved:

* runtime;
* logs;
* reports;
* migrated user data.

Package lifecycle remains the responsibility of the calling deployment or management platform.

## Intune Managed-Device Validation

Actual Microsoft Intune Win32 assignment to a managed test device has been deferred.

Local package creation, deployment, uninstall, persistent-data handling, runtime execution and detection behaviour have been validated.

The remaining managed-device test is considered external platform integration validation.

## Development Build State

The validated E2E packages report:

* Version: `0.2.0`
* Build: `Development`

The packages were generated from a dirty Git working tree because DEF-01, DEF-02, DEF-03 and Milestone 5 validation additions had not yet been committed.

This is appropriate for development validation.

A clean release artifact should be generated after the Milestone 5 changes have been committed and merged.

---

# Milestone 5 Acceptance Criteria

Milestone 5 technical implementation is accepted when:

* automated M5 validation passes;
* M3 automated regression passes;
* standalone package execution is validated;
* successful silent migration is validated;
* external configuration and migration profile selection are validated;
* LocalSystem execution is validated;
* remote/RMM execution is validated;
* Intune package lifecycle and detection behaviour are validated;
* code signing and package integrity validation pass;
* defects identified during E2E validation are resolved and retested;
* regression coverage exists for identified functional defects where appropriate;
* no critical Milestone 5 defects remain open;
* known limitations and deferred platform tests are documented;
* final regression validation passes.

All technical criteria above have been satisfied.

The remaining Microsoft Intune managed-device test is documented as deferred external platform integration validation.

---

# Current Milestone 5 Status

| Validation                                 | Status           |
| ------------------------------------------ | ---------------- |
| Automated M5 validation                    | **PASS – 13/13** |
| M3 automated regression                    | **PASS – 47/47** |
| E2E-01 – Standalone runtime                | **PASS**         |
| E2E-02 – Silent migration                  | **PASS**         |
| E2E-03 – External configuration            | **PASS**         |
| E2E-04 – LocalSystem execution             | **PASS**         |
| E2E-05 – Remote/RMM execution              | **PASS**         |
| E2E-06 – Intune local lifecycle            | **PASS**         |
| E2E-06 – Intune managed-device integration | **DEFERRED**     |
| E2E-07 – Signed release package            | **PASS**         |
| E2E-08 – Final regression                  | **PASS**         |
| DEF-01                                     | **RESOLVED**     |
| DEF-02                                     | **RESOLVED**     |
| DEF-03                                     | **RESOLVED**     |

## Final Status

**MILESTONE 5 TECHNICAL VALIDATION: PASS**

Milestone 5 Deployment & Automation has successfully completed technical validation.

The final automated regression completed with:

* **13/13 M5 suites passed**
* **47/47 M3 regression tests passed**
* **0 failed suites**
* **0 failed M3 tests**

E2E-01 through E2E-05, E2E-07 and E2E-08 passed completely.

The Intune packaging and local deployment lifecycle in E2E-06 also passed, including detection of incomplete installations after DEF-03.

Three defects were identified during end-to-end validation:

* DEF-01 – Launcher argument and exit-code handling;
* DEF-02 – Configured default migration profile resolution;
* DEF-03 – Intune incomplete-install detection.

All three defects were corrected, regression-tested and successfully included in the final E2E-08 regression.

Actual Microsoft Intune deployment to a managed test device remains deferred as an external platform integration test and is not considered a blocker for Milestone 5 technical completion.

A clean release artifact should be generated after the validated changes have been committed and merged.
