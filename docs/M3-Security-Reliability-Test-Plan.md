# M3 – Security & Reliability Test Plan

## 1. Purpose

This document defines the validation test plan and final test results for Milestone 3 – Reliability & Security.

The purpose of this test plan is to verify that ProfMig behaves safely, predictably and recoverably under both normal and failure conditions.

Testing focuses specifically on functionality delivered during Milestone 3, including:

* Profile and privilege validation
* Storage capacity validation
* File access and locked-file handling
* Permissions and ACL handling
* Error handling and recovery
* Migration verification and integrity checking
* Logging and reporting
* Security behaviour

Milestone 3 may only be considered complete when all critical test scenarios have been executed and no unresolved critical defects remain.

---

# 2. Test objectives

The validation must demonstrate that:

* Unsafe migrations are prevented before data is copied.
* Critical validation failures stop the migration.
* Non-critical errors are handled predictably.
* File-level failures do not cause uncontrolled migration failure.
* Insufficient storage is detected before migration.
* Destination permissions allow the destination user to access migrated data.
* Source security and source data are not unexpectedly modified.
* Interrupted or partially failed migrations can be handled safely.
* Migration integrity can be verified.
* Security controls are not bypassed.
* Errors are correctly logged and reported.
* Critical defects are resolved and retested before M3 completion.

---

# 3. Test result definitions

Each testcase receives one of the following results.

| Result | Meaning |
| --- | --- |
| PASS | Actual behaviour matches expected behaviour |
| FAIL | Actual behaviour does not match expected behaviour |
| BLOCKED | Test cannot currently be executed |
| N/A | Test is not applicable to the current implementation |

A testcase resulting in `FAIL` must be evaluated to determine whether remediation or a GitHub issue is required.

Critical defects must be resolved before Milestone 3 can be completed.

A testcase that initially failed but passed after remediation is recorded as `PASS`, with the initial failure and remediation documented in the actual result.

---

# 4. Evidence requirements

For executed testcases, evidence may include:

* Test date
* ProfMig Git commit
* Source and destination profiles or controlled test paths
* Test conditions
* Expected result
* Actual result
* PASS / FAIL / BLOCKED / N/A
* Relevant log file
* Relevant report
* PowerShell output
* Remediation commit where applicable

Milestone 3 final validation was executed on 28 August 2026 on the Sprint 3.8 feature branch.

---

# 5. Profile validation tests

## M3-VAL-01 – Source profile does not exist

**Purpose**

Verify that ProfMig prevents migration when the selected source profile does not exist.

**Test**

Select or specify a non-existing source profile.

**Expected result**

* Validation fails.
* Migration does not start.
* Error is classified as a validation failure.
* Failure is logged.
* No destination data is created or modified.

**Actual result**

A non-existing source profile was supplied to the validation workflow. ProfMig rejected the source before migration and returned a validation failure. No migration data was copied.

**Result:** PASS

---

## M3-VAL-02 – Destination profile does not exist

**Purpose**

Verify behaviour when the destination profile does not exist.

**Test**

Specify a non-existing destination profile.

**Expected result**

* ProfMig handles the condition according to the implemented profile validation policy.
* Unsafe migration does not start.
* Condition is logged and reported.

**Actual result**

A non-existing destination profile was supplied. Profile validation rejected the destination and prevented unsafe migration.

**Result:** PASS

---

## M3-VAL-03 – Source equals destination

**Purpose**

Prevent ProfMig from copying a profile onto itself.

**Test**

Select the same profile as source and destination.

**Expected result**

* Critical validation failure.
* Migration is blocked.
* No files are copied.
* Failure is logged.

**Actual result**

Source and destination were configured to the same profile. ProfMig detected the condition during validation and blocked migration before copying data.

**Result:** PASS

---

## M3-VAL-04 – Invalid profile path

**Test**

Use a profile with an invalid or unavailable profile path.

**Expected result**

* Validation detects the invalid path.
* Migration does not start.
* Clear validation error is generated.
* Error is logged.

**Actual result**

An invalid source path was tested. Validation failed and migration did not start.

**Result:** PASS

---

## M3-VAL-05 – Inaccessible source profile

**Test**

Remove or deny access to the source profile for the migration process.

**Expected result**

* Access problem is detected.
* ProfMig does not silently continue as if validation succeeded.
* Error classification identifies the access problem.
* Failure is logged.

**Actual result**

Source access was deliberately restricted. ProfMig detected the inaccessible source and did not silently treat validation as successful.

**Result:** PASS

---

# 6. Privilege tests

## M3-PRIV-01 – Run elevated

**Test**

Start ProfMig with administrative privileges.

**Expected result**

* Privilege validation succeeds.
* Migration is allowed to continue when other validation requirements are met.

**Actual result**

ProfMig was executed from an elevated PowerShell session. Administrative privilege validation succeeded and execution was allowed to continue.

**Result:** PASS

---

## M3-PRIV-02 – Run without required privileges

**Test**

Start ProfMig without administrative elevation.

**Expected result**

* Missing privileges are detected.
* Migration is blocked before copying data.
* Critical validation error is generated.
* Failure is logged.

**Actual result**

ProfMig was tested without the required administrative elevation. The missing privilege condition was detected and execution was prevented from proceeding into migration.

**Result:** PASS

---

## M3-PRIV-03 – Destination directory not writable

**Test**

Configure a destination directory where ProfMig cannot create or modify files.

**Expected result**

* Write failure is detected.
* Failure is correctly classified.
* ProfMig does not report the affected file as successfully migrated.
* Error appears in logging/reporting.

**Actual result**

Write access to the controlled destination was denied. ProfMig detected the destination write failure and did not classify the affected item as successfully migrated.

**Result:** PASS

---

## M3-PRIV-04 – Source file access denied

**Test**

Create a source file to which the migration process has no read access.

**Expected result**

* Access denied condition is detected.
* Error is classified correctly.
* Behaviour follows configured recovery policy.
* Migration does not terminate uncontrollably.
* File is reported as failed/skipped.

**Actual result**

An explicit Windows ACL deny rule was used to prevent source-file access. ProfMig detected the access failure, classified the file failure and handled it according to the recovery policy without uncontrolled termination.

**Result:** PASS

---

# 7. Storage tests

## M3-STOR-01 – Sufficient disk space

**Expected result**

* Storage validation succeeds.
* Migration may proceed.

**Actual result**

A migration selection with sufficient destination capacity was validated successfully and allowed to proceed.

**Result:** PASS

---

## M3-STOR-02 – Disk space close to minimum

**Test**

Use a migration selection that leaves destination storage close to the configured warning threshold.

**Expected result**

* Storage validation returns a warning.
* Required and available storage are reported.
* Behaviour follows configured storage policy.

**Actual result**

A controlled selection was used that left destination capacity within the configured warning threshold. ProfMig returned a warning and reported the relevant capacity information.

**Result:** PASS

---

## M3-STOR-03 – Insufficient disk space

**Expected result**

* Insufficient storage is detected before migration.
* Critical validation failure is generated.
* Migration does not start.
* Required and available storage are logged.

**Actual result**

A migration selection requiring more storage than available was evaluated. ProfMig detected insufficient capacity before migration and returned a critical storage validation failure.

**Result:** PASS

---

## M3-STOR-04 – Large source profile

**Test**

Validate a source profile containing a large amount of data.

**Expected result**

* Profile size is calculated without uncontrolled failure.
* Required storage includes the configured safety margin.
* Result accurately reflects destination capacity.

**Actual result**

A large source profile was evaluated successfully. ProfMig calculated approximately 184 GB of selected source data and approximately 221 GB required after applying the configured safety margin. Available destination capacity was correctly evaluated as insufficient.

**Result:** PASS

---

# 8. File handling tests

## M3-FILE-01 – Locked file

**Test**

Keep a source file exclusively locked while migration runs.

**Expected result**

* Locked file is detected.
* Retry behaviour is executed according to configuration.
* Failure does not crash the complete migration.
* File result contains the correct failure classification.
* Failure is logged and reported.

**Actual result**

A controlled locked file was processed. ProfMig detected the lock, applied the configured retry behaviour and returned a traceable file-level failure without terminating the complete migration.

**Result:** PASS

---

## M3-FILE-02 – File removed during migration

**Test**

Delete a source file after enumeration but before it is copied.

**Expected result**

* Missing source file is detected.
* Error is classified correctly.
* Migration continues when the condition is non-critical.
* File is not reported as successfully migrated.

**Actual result**

A source file was removed between selection and copy. ProfMig detected the missing source, classified the condition and did not report the file as successfully copied.

**Result:** PASS

---

## M3-FILE-03 – Destination file already exists

**Test**

Create a destination file before migration.

**Expected result**

* Existing destination file is handled according to the configured copy policy.
* Behaviour is deterministic.
* Result is logged.

**Actual result**

An existing destination file was introduced before copy. ProfMig handled the condition consistently according to the implemented copy behaviour.

**Result:** PASS

---

## M3-FILE-04 – Read failure

**Test**

Force a source read operation to fail.

**Expected result**

* Read failure is detected.
* File is not reported as successful.
* Error classification and recovery behaviour are correct.

**Actual result**

A controlled source read failure was introduced. The operation was classified correctly and the affected file was not reported as successfully migrated.

**Result:** PASS

---

## M3-FILE-05 – Write failure

**Test**

Force a destination write operation to fail.

**Expected result**

* Destination write failure is detected.
* Partial/incomplete file is not treated as a successful migration.
* Error is logged and reported.

**Actual result**

A controlled destination write failure was introduced. ProfMig detected the failure and did not treat the affected operation as successful.

**Result:** PASS

---

## M3-FILE-06 – Large file

**Test**

Migrate one or more large files.

**Expected result**

* File is copied successfully.
* File size at destination matches source.
* Verification succeeds.

**Actual result**

Large-file migration completed successfully. Destination size matched the source and verification completed successfully.

**Result:** PASS

---

## M3-FILE-07 – Large number of small files

**Test**

Migrate a directory containing a large number of small files.

**Expected result**

* Migration completes without uncontrolled failure.
* File counts are accurate.
* Errors, if present, remain traceable to individual files.
* Verification results are accurate.

**Actual result**

A controlled directory containing a large number of files was migrated. The operation completed without uncontrolled failure and file-level results remained traceable.

**Result:** PASS

---

# 9. Permissions and ACL tests

## M3-ACL-01 – Different source and destination SID

**Test**

Migrate data between two users with different Windows SIDs.

**Expected result**

* Destination user receives appropriate access.
* Source SID is not incorrectly required for destination access.
* ACL validation succeeds after migration/repair.

**Actual result**

Migration and ACL validation were tested using different source and destination identities. Destination access could be established without relying on the source SID.

**Result:** PASS

---

## M3-ACL-02 – Inherited ACL

**Test**

Migrate files using inherited permissions.

**Expected result**

* Inheritance remains valid or is correctly established at destination.
* Destination user can access migrated data.

**Actual result**

Inherited destination permissions were evaluated and remained valid for destination access.

**Result:** PASS

---

## M3-ACL-03 – Explicit ACL

**Test**

Migrate files containing explicit ACL entries.

**Expected result**

* ProfMig handles explicit permissions according to its ACL strategy.
* Destination access remains valid.
* Security is not unnecessarily weakened.

**Actual result**

Explicit ACL behaviour was tested. ProfMig applied its destination access strategy without introducing unnecessarily broad permissions.

**Result:** PASS

---

## M3-ACL-04 – Destination user access verification

**Test**

Validate destination data using the destination user's SID.

**Expected result**

* ACL validation confirms effective destination access.
* Invalid destination permissions are detected.
* Permission repair, where supported, produces a verifiable result.

**Actual result**

Destination access validation detected an invalid permission state and permission repair produced a valid destination access result.

The tested repair strategy reported `ExplicitDestinationAccess`, with validation changing from invalid before repair to valid after repair.

**Result:** PASS

---

## M3-ACL-05 – No Everyone Full Control

**Expected result**

ProfMig must not grant:

`Everyone: Full Control`

as a generic solution to permission problems.

**Actual result**

Destination ACLs were inspected after permission handling. ProfMig did not introduce `Everyone: Full Control`.

**Result:** PASS

---

# 10. Recovery tests

## M3-REC-01 – Interrupt migration

**Test**

Terminate ProfMig while files are being copied.

**Expected result**

* Existing source data remains unchanged.
* Already completed destination files remain identifiable.
* Incomplete operations do not result in a false successful migration status.

**Actual result**

Migration interruption was tested. Existing source data remained intact and the resulting migration state was not falsely represented as a complete success.

**Result:** PASS

---

## M3-REC-02 – Re-run interrupted migration

**Test**

Start ProfMig again after M3-REC-01.

**Expected result**

* Re-running does not cause uncontrolled errors.
* Existing destination data is handled predictably.
* Migration can complete where designed.

**Actual result**

The interrupted migration scenario was re-run. Existing destination data was handled predictably and the migration could continue without uncontrolled errors.

**Result:** PASS

---

## M3-REC-03 – Non-critical error

**Test**

Introduce a recoverable/non-critical file error.

**Expected result**

* Error is recorded.
* Recovery policy is applied.
* Remaining eligible files continue migrating.
* Final result does not hide the failure.

**Actual result**

A controlled non-critical file failure was introduced. The failure was recorded, the configured recovery behaviour was applied and remaining eligible work could continue.

**Result:** PASS

---

## M3-REC-04 – Critical error

**Test**

Trigger a condition classified as critical.

**Expected result**

* ProfMig stops safely.
* Critical error is logged.
* Correct exit behaviour is used.
* Migration is not reported as successful.

**Actual result**

A controlled critical condition was triggered. ProfMig classified the condition as critical, selected `Stop` recovery behaviour and did not represent the migration as successful.

**Result:** PASS

---

## M3-REC-05 – Partial migration behaviour

**Test**

Create a migration containing successful and deliberately failing files.

**Expected result**

* Successful files are distinguishable from failed files.
* Partial migration is not reported as a complete success.
* Failed items can be identified from logs/reports.

**Actual result**

A controlled migration containing both successful and failing files was executed. Successful and failed items remained distinguishable and the final result did not hide the failure.

**Result:** PASS

---

# 11. Integrity and verification tests

## M3-VER-01 – Successful verification

**Test**

Perform a migration without introduced failures and run migration verification.

**Expected result**

* Source and destination match according to the implemented verification policy.
* Verification status is successful.

**Actual result**

A successful migration was verified using the implemented verification framework. Source and destination matched and verification returned success.

**Result:** PASS

---

## M3-VER-02 – Missing destination file

**Test**

Delete a migrated destination file before verification.

**Expected result**

* Verification detects the missing file.
* Migration is not considered fully verified.
* Missing file is identifiable.

**Actual result**

A destination file was deliberately removed before verification. ProfMig detected that the destination file was missing and verification failed for the affected item.

**Result:** PASS

---

## M3-VER-03 – Modified destination file

**Test**

Modify a destination file after migration.

**Expected result**

* Modification is detected where covered by the implemented verification method.
* Verification reports the mismatch.

**Actual result**

Destination content was modified after copy. Verification detected that source and destination no longer matched.

**Result:** PASS

---

## M3-VER-04 – File-size mismatch

**Test**

Change the size of a destination file.

**Expected result**

* Size mismatch is detected.
* Affected file is identified.
* Verification fails or warns according to policy.

**Actual result**

Different source and destination sizes were introduced. Verification returned `Status=Failed`, `Reason=SizeMismatch` and `Verified=False`.

**Result:** PASS

---

## M3-VER-05 – Hash mismatch

**Test**

Modify destination file content while preserving its size where possible.

Run hash verification when supported/enabled.

**Expected result**

* Hash comparison identifies different content.
* File is reported as mismatched.

**Actual result**

Hash verification using SHA256 was tested with equal-size files containing different content. The hash comparison detected the content mismatch and verification failed for the affected file.

Hash verification is implemented and available through the optional `Hash` verification level.

**Result:** PASS

---

# 12. Security validation

## M3-SEC-01 – No global Windows security weakening

Verify that ProfMig does not:

* Disable UAC
* Disable Windows security services
* Disable ACL enforcement
* Modify global security policy unnecessarily
* Disable security controls to complete a migration

**Expected result**

ProfMig does not weaken global Windows security controls.

**Actual result**

Windows security state was compared around a real ProfMig copy operation. No evidence was found that ProfMig disabled UAC, Windows Firewall, relevant security services or global ACL enforcement.

**Result:** PASS

---

## M3-SEC-02 – No Everyone Full Control

Inspect destination ACLs after permission repair.

**Expected result**

ProfMig does not grant broad `Everyone: Full Control` permissions.

**Actual result**

Destination permissions were inspected after ACL repair. No `Everyone: Full Control` entry was introduced.

**Result:** PASS

---

## M3-SEC-03 – Windows access controls are respected

**Expected result**

ProfMig handles access failures through validation, classification, logging and recovery.

It must not attempt to bypass Windows access controls through unsafe global configuration changes.

**Actual result**

An explicit Windows `Deny ReadData` rule was applied to a controlled source file. ProfMig respected the Windows access decision and returned a `PermissionError` / `AccessDenied` result. No destination file was created and the source ACL remained unchanged.

**Result:** PASS

---

## M3-SEC-04 – Credentials are not exposed

Inspect:

* Console output
* ProfMig logs
* Migration reports
* Error details

**Expected result**

No passwords, authentication secrets, tokens or other credentials are exposed.

**Actual result**

Initial testing identified that controlled fake credential values embedded in diagnostic text could appear in logs and reports.

Central sensitive-text redaction was implemented in the logging framework and applied to report output. The remediation covers common password, token, API key, secret, client secret, authorization and HTTP Bearer credential patterns.

The testcase was repeated after remediation. No controlled secret markers remained in the generated log or report. Sensitive values were replaced by `[REDACTED]`.

**Remediation**

Commit `c899ec5` – `fix: redact sensitive data from logs and reports`

**Result:** PASS

---

## M3-SEC-05 – No credential decryption

**Expected result**

ProfMig does not attempt to decrypt or extract stored user credentials.

**Actual result**

Static inspection found no use of credential extraction or decryption mechanisms such as DPAPI unprotect operations, Credential Manager enumeration or Windows Password Vault access.

The application exclusion framework was also inspected at runtime. Security-sensitive credential stores including Windows Credentials, DPAPI Protect data, Windows Vault data and browser `Login Data` were covered by mandatory security exclusions.

**Result:** PASS

---

## M3-SEC-06 – Source data remains unchanged

Compare selected source data before and after migration.

**Expected result**

* Source files are not deleted.
* Source files are not modified as part of migration.
* Source ACLs are not unexpectedly changed.

**Actual result**

A controlled source file was measured before and after migration.

The source file remained present and its size, SHA256 hash, last-write timestamp and ACL remained unchanged. The destination file was created and matched the source.

**Result:** PASS

---

## M3-SEC-07 – Security failures are visible

Trigger an access or permission related failure.

**Expected result**

* Security-related failure is logged.
* Failure appears in reporting where applicable.
* Failure is not silently ignored.
* Final migration status accurately reflects the condition.

**Actual result**

A controlled source file was protected with an explicit `Deny ReadData` ACL.

The copy operation returned a failed item classified as:

* Category: `PermissionError`
* Severity: `Error`
* Reason: `AccessDenied`
* Recovery action: `Skip`

No destination file was created.

The structured failure was visible in logging and reporting. The generated migration report contained the permission error, access-denied reason and failed migration state.

A first reporting attempt used an incomplete synthetic reporting wrapper and was therefore discarded as test-harness error. The corrected test completed successfully.

**Result:** PASS

---

# 13. Logging validation

## M3-LOG-01 – Successful operation logging

Verify that normal migration activity produces the expected logging.

**Actual result**

Controlled successful operations produced timestamped `INFO` and `SUCCESS` entries. Startup, processing and successful completion messages were present in the generated logfile.

**Result:** PASS

---

## M3-LOG-02 – Warning logging

Trigger a warning condition.

**Expected result**

Warning is identifiable in the log with sufficient context.

**Actual result**

A controlled warning was written to the logging framework. The logfile contained the expected timestamped `WARNING` entry and message.

**Result:** PASS

---

## M3-LOG-03 – Error logging

Trigger a non-critical error.

**Expected result**

Log identifies:

* Component
* Operation
* Error category/reason
* Severity where applicable
* Recovery behaviour
* Affected file/path where appropriate

**Actual result**

A controlled structured `SourceReadError` was logged.

The resulting log entry preserved the error level, category, severity, component, reason and recovery action and included a timestamp and diagnostic message.

**Result:** PASS

---

## M3-LOG-04 – Critical failure logging

Trigger a critical validation or migration failure.

**Expected result**

Critical condition is clearly visible and traceable.

**Actual result**

Initial testing showed that an error with `Severity=Critical` retained its structured severity metadata but was emitted using the primary `[ERROR]` log level.

The logging severity mapping was corrected so critical ProfMig errors are emitted using `[CRITICAL]`.

Retesting produced:

`[CRITICAL] [Category=ValidationError | Severity=Critical | Component=M3-LOG-04 | Reason=ControlledCriticalFailure | Recovery=Stop]`

The critical level, severity, category, reason, recovery action and timestamp were all verified.

**Remediation**

Commit `6581723` – `fix: preserve critical severity in logging`

**Result:** PASS

---

## M3-LOG-05 – Sensitive information

Review generated logs.

**Expected result**

Logs contain sufficient diagnostic information without exposing credentials or secrets.

**Actual result**

Combined diagnostic logging was tested using informational, warning, error and critical events.

All log entries were timestamped and the log retained sufficient diagnostic context including component, category, reason and recovery behaviour.

Sensitive-data testing performed under M3-SEC-04 confirmed that credential and secret values are redacted before being written to ProfMig logs.

**Result:** PASS

---

# 14. Reporting validation

## M3-RPT-01 – Successful migration report

**Expected result**

Report correctly represents a successful migration.

**Actual result**

A real end-to-end migration was completed and a migration report was generated. The report correctly represented the successful migration and included verification information.

During reporting validation, verification metadata propagation was improved so `VerificationLevel` and `HashAlgorithm` are correctly preserved from copy totals into the migration result.

**Remediation**

Commit `dca3841` – `fix: preserve verification metadata in reports`

**Result:** PASS

---

## M3-RPT-02 – Partial migration report

**Expected result**

Successful and failed items are distinguishable.

**Actual result**

A controlled migration was executed containing one readable file and one source file protected by an explicit `Deny ReadData` rule.

Results:

* Successful destination file existed.
* Failed destination file was absent.
* Files copied: 1
* Files failed: 1
* Failed filename was visible in the report.
* `AccessDenied` was visible in the report.
* Overall migration status was `Failed`.

The partial migration was therefore not represented as a complete success.

**Result:** PASS

---

## M3-RPT-03 – Failed migration report

**Expected result**

Critical failure is visible and the migration is not represented as successful.

**Actual result**

A controlled structured critical validation error was supplied to reporting with:

* Category: `ValidationError`
* Severity: `Critical`
* Component: `M3-RPT-03`
* Operation: `Validation`
* Reason: `ControlledCriticalFailure`
* Recovery action: `Stop`

The generated report contained the critical severity, category, reason, failure message and stop recovery action.

Overall migration status was `Failed` and was not represented as successful.

**Result:** PASS

---

## M3-RPT-04 – Verification result

**Expected result**

Migration verification result is represented accurately in reporting.

**Actual result**

Positive verification reporting was tested using `Hash` verification with `SHA256`.

The migration result and report correctly showed:

* Files verified: 1
* Verification failures: 0
* Verification level: `Hash`
* Hash algorithm: `SHA256`

Negative verification reporting was also tested. A real verification operation using different-size source and destination files returned:

* Status: `Failed`
* Reason: `SizeMismatch`
* Verified: `False`

A controlled verification failure was then supplied to the reporting layer. The report correctly showed one verification failure, verification error information, Hash/SHA256 metadata and a failed overall migration status.

The runtime mismatch in this negative reporting testcase was a `SizeMismatch`; it is not recorded as a runtime `HashMismatch`.

**Result:** PASS

---

# 15. Defect handling and remediation

Defects discovered during Sprint 3.8 were evaluated and remediated before final Milestone 3 approval.

| Area | Finding | Resolution | Commit | Final status |
| --- | --- | --- | --- | --- |
| Reporting | Verification level and hash algorithm metadata were not reliably preserved in the final migration result/report | Reporting conversion updated to preserve verification metadata | `dca3841` | Resolved and retested |
| Security | Sensitive credential-like values in diagnostic messages could be written to logs and reports | Central sensitive-text redaction added to logging and reporting | `c899ec5` | Resolved and retested |
| Logging | `Severity=Critical` was emitted using the primary `ERROR` log level | Critical severity now maps to the `CRITICAL` log level | `6581723` | Resolved and retested |

No unresolved critical or high-severity defects remain from the Milestone 3 validation.

---

# 16. Known limitations and observations

The following observations were recorded during testing.

| ID | Observation / limitation | Impact | Status |
| --- | --- | --- | --- |
| M3-OBS-01 | Verification performs existence and size checks before hash comparison. A size difference therefore produces `SizeMismatch` without calculating hashes. | Expected verification behaviour; size mismatch already proves files differ. | Accepted |
| M3-OBS-02 | Hash verification is optional and is performed when verification level `Hash` is selected. | Standard verification does not provide content-level hash comparison. | By design |
| M3-OBS-03 | Sensitive-text redaction is pattern-based and protects common credential assignments and Bearer tokens in diagnostic output. | Future diagnostic formats containing new secret patterns may require additional redaction patterns. | Accepted |
| M3-OBS-04 | Some controlled tests use synthetic result wrappers to exercise reporting independently of the interactive migration workflow. | Reporting-layer behaviour is validated independently; end-to-end reporting was also tested separately. | Accepted |

No known limitation identified during this validation prevents Milestone 3 approval.

---

# 17. Test execution summary

| Area | Total | Pass | Fail | Blocked | N/A |
| --- | ---: | ---: | ---: | ---: | ---: |
| Profile validation | 5 | 5 | 0 | 0 | 0 |
| Privileges | 4 | 4 | 0 | 0 | 0 |
| Storage | 4 | 4 | 0 | 0 | 0 |
| File handling | 7 | 7 | 0 | 0 | 0 |
| Permissions / ACL | 5 | 5 | 0 | 0 | 0 |
| Recovery | 5 | 5 | 0 | 0 | 0 |
| Integrity / verification | 5 | 5 | 0 | 0 | 0 |
| Security | 7 | 7 | 0 | 0 | 0 |
| Logging | 5 | 5 | 0 | 0 | 0 |
| Reporting | 4 | 4 | 0 | 0 | 0 |
| **Total** | **51** | **51** | **0** | **0** | **0** |

---

# 18. Milestone 3 acceptance criteria

M3 acceptance criteria after final validation:

* [x] Critical validation failures prevent unsafe migration.
* [x] Non-critical errors are handled predictably.
* [x] Insufficient disk space is detected.
* [x] Locked files do not cause uncontrolled failure.
* [x] Destination permissions are correct.
* [x] Migration failures are recoverable where designed.
* [x] Migration integrity can be verified.
* [x] Security controls are not bypassed.
* [x] Logging correctly represents warnings and failures.
* [x] Reporting correctly represents migration outcome.
* [x] All critical defects discovered during M3 testing are resolved.
* [x] Resolved defects have been retested.
* [x] Known limitations and observations are documented.
* [x] No unresolved critical defects remain.

---

# 19. Final M3 validation

**Sprint:** 3.8 – Security & Reliability Validation
**Milestone:** M3 – Reliability & Security
**Validation date:** 28 August 2026
**Validation branch:** `feature/sprint-3.8-security-reliability-validation`

**Overall result:** PASS
**Tests executed:** 51
**Tests passed:** 51
**Tests failed:** 0
**Tests blocked:** 0
**Tests N/A:** 0
**Open critical defects:** 0
**Open high defects:** 0

## Remediation commits

* `dca3841` – `fix: preserve verification metadata in reports`
* `c899ec5` – `fix: redact sensitive data from logs and reports`
* `6581723` – `fix: preserve critical severity in logging`

## Final conclusion

All 51 Milestone 3 validation scenarios have been executed successfully.

The validation demonstrates that ProfMig prevents unsafe migration conditions, validates storage and permissions, handles file-level failures predictably, supports controlled recovery behaviour, verifies migrated data, respects Windows security controls and provides traceable logging and reporting.

Issues discovered during validation were remediated and retested successfully. No unresolved critical or high-severity defects remain from the Milestone 3 validation.

Based on the executed test scenarios and documented results, Milestone 3 – Reliability & Security meets its defined acceptance criteria.

**M3 status: APPROVED**