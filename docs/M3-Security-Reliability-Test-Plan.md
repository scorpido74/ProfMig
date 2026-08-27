# M3 – Security & Reliability Test Plan

## 1. Purpose

This document defines the validation test plan for Milestone 3 – Reliability & Security.

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

Each testcase must receive one of the following results.

| Result  | Meaning                                              |
| ------- | ---------------------------------------------------- |
| PASS    | Actual behaviour matches expected behaviour          |
| FAIL    | Actual behaviour does not match expected behaviour   |
| BLOCKED | Test cannot currently be executed                    |
| N/A     | Test is not applicable to the current implementation |

A testcase resulting in `FAIL` must be evaluated to determine whether a GitHub issue is required.

Critical defects must be resolved before Milestone 3 can be completed.

---

# 4. Evidence requirements

For every executed testcase record:

* Test date
* ProfMig version or Git commit
* Source profile
* Destination profile
* Test conditions
* Expected result
* Actual result
* PASS / FAIL / BLOCKED / N/A
* Relevant log file
* Relevant report
* GitHub issue number when applicable

Relevant PowerShell output may also be included as evidence.

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

**Result:** NOT TESTED

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

**Result:** NOT TESTED

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

**Result:** NOT TESTED

---

## M3-VAL-04 – Invalid profile path

**Test**

Use a profile with an invalid or unavailable profile path.

**Expected result**

* Validation detects the invalid path.
* Migration does not start.
* Clear validation error is generated.
* Error is logged.

**Result:** NOT TESTED

---

## M3-VAL-05 – Inaccessible source profile

**Test**

Remove or deny access to the source profile for the migration process.

**Expected result**

* Access problem is detected.
* ProfMig does not silently continue as if validation succeeded.
* Error classification identifies the access problem.
* Failure is logged.

**Result:** NOT TESTED

---

# 6. Privilege tests

## M3-PRIV-01 – Run elevated

**Test**

Start ProfMig with administrative privileges.

**Expected result**

* Privilege validation succeeds.
* Migration is allowed to continue when other validation requirements are met.

**Result:** NOT TESTED

---

## M3-PRIV-02 – Run without required privileges

**Test**

Start ProfMig without administrative elevation.

**Expected result**

* Missing privileges are detected.
* Migration is blocked before copying data.
* Critical validation error is generated.
* Failure is logged.

**Result:** NOT TESTED

---

## M3-PRIV-03 – Destination directory not writable

**Test**

Configure a destination directory where ProfMig cannot create or modify files.

**Expected result**

* Write failure is detected.
* Failure is correctly classified.
* ProfMig does not report the affected file as successfully migrated.
* Error appears in logging/reporting.

**Result:** NOT TESTED

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

**Result:** NOT TESTED

---

# 7. Storage tests

## M3-STOR-01 – Sufficient disk space

**Expected result**

* Storage validation succeeds.
* Migration may proceed.

**Result:** NOT TESTED

---

## M3-STOR-02 – Disk space close to minimum

**Test**

Use a migration selection that leaves destination storage close to the configured warning threshold.

**Expected result**

* Storage validation returns a warning.
* Required and available storage are reported.
* Behaviour follows configured storage policy.

**Result:** NOT TESTED

---

## M3-STOR-03 – Insufficient disk space

**Expected result**

* Insufficient storage is detected before migration.
* Critical validation failure is generated.
* Migration does not start.
* Required and available storage are logged.

**Result:** NOT TESTED

---

## M3-STOR-04 – Large source profile

**Test**

Validate a source profile containing a large amount of data.

**Expected result**

* Profile size is calculated without uncontrolled failure.
* Required storage includes the configured safety margin.
* Result accurately reflects destination capacity.

**Result:** NOT TESTED

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

**Result:** NOT TESTED

---

## M3-FILE-02 – File removed during migration

**Test**

Delete a source file after enumeration but before it is copied.

**Expected result**

* Missing source file is detected.
* Error is classified correctly.
* Migration continues when the condition is non-critical.
* File is not reported as successfully migrated.

**Result:** NOT TESTED

---

## M3-FILE-03 – Destination file already exists

**Test**

Create a destination file before migration.

**Expected result**

* Existing destination file is handled according to the configured copy policy.
* Behaviour is deterministic.
* Result is logged.

**Result:** NOT TESTED

---

## M3-FILE-04 – Read failure

**Test**

Force a source read operation to fail.

**Expected result**

* Read failure is detected.
* File is not reported as successful.
* Error classification and recovery behaviour are correct.

**Result:** NOT TESTED

---

## M3-FILE-05 – Write failure

**Test**

Force a destination write operation to fail.

**Expected result**

* Destination write failure is detected.
* Partial/incomplete file is not treated as a successful migration.
* Error is logged and reported.

**Result:** NOT TESTED

---

## M3-FILE-06 – Large file

**Test**

Migrate one or more large files.

**Expected result**

* File is copied successfully.
* File size at destination matches source.
* Verification succeeds.

**Result:** NOT TESTED

---

## M3-FILE-07 – Large number of small files

**Test**

Migrate a directory containing a large number of small files.

**Expected result**

* Migration completes without uncontrolled failure.
* File counts are accurate.
* Errors, if present, remain traceable to individual files.
* Verification results are accurate.

**Result:** NOT TESTED

---

# 9. Permissions and ACL tests

## M3-ACL-01 – Different source and destination SID

**Test**

Migrate data between two users with different Windows SIDs.

**Expected result**

* Destination user receives appropriate access.
* Source SID is not incorrectly required for destination access.
* ACL validation succeeds after migration/repair.

**Result:** NOT TESTED

---

## M3-ACL-02 – Inherited ACL

**Test**

Migrate files using inherited permissions.

**Expected result**

* Inheritance remains valid or is correctly established at destination.
* Destination user can access migrated data.

**Result:** NOT TESTED

---

## M3-ACL-03 – Explicit ACL

**Test**

Migrate files containing explicit ACL entries.

**Expected result**

* ProfMig handles explicit permissions according to its ACL strategy.
* Destination access remains valid.
* Security is not unnecessarily weakened.

**Result:** NOT TESTED

---

## M3-ACL-04 – Destination user access verification

**Test**

Validate destination data using the destination user's SID.

**Expected result**

* ACL validation confirms effective destination access.
* Invalid destination permissions are detected.
* Permission repair, where supported, produces a verifiable result.

**Result:** NOT TESTED

---

## M3-ACL-05 – No Everyone Full Control

**Expected result**

ProfMig must not grant:

`Everyone: Full Control`

as a generic solution to permission problems.

**Result:** NOT TESTED

---

# 10. Recovery tests

## M3-REC-01 – Interrupt migration

**Test**

Terminate ProfMig while files are being copied.

**Expected result**

* Existing source data remains unchanged.
* Already completed destination files remain identifiable.
* Incomplete operations do not result in a false successful migration status.

**Result:** NOT TESTED

---

## M3-REC-02 – Re-run interrupted migration

**Test**

Start ProfMig again after M3-REC-01.

**Expected result**

* Re-running does not cause uncontrolled errors.
* Existing destination data is handled predictably.
* Migration can complete where designed.

**Result:** NOT TESTED

---

## M3-REC-03 – Non-critical error

**Test**

Introduce a recoverable/non-critical file error.

**Expected result**

* Error is recorded.
* Recovery policy is applied.
* Remaining eligible files continue migrating.
* Final result does not hide the failure.

**Result:** NOT TESTED

---

## M3-REC-04 – Critical error

**Test**

Trigger a condition classified as critical.

**Expected result**

* ProfMig stops safely.
* Critical error is logged.
* Correct exit behaviour is used.
* Migration is not reported as successful.

**Result:** NOT TESTED

---

## M3-REC-05 – Partial migration behaviour

**Test**

Create a migration containing successful and deliberately failing files.

**Expected result**

* Successful files are distinguishable from failed files.
* Partial migration is not reported as a complete success.
* Failed items can be identified from logs/reports.

**Result:** NOT TESTED

---

# 11. Integrity and verification tests

## M3-VER-01 – Successful verification

**Test**

Perform a migration without introduced failures and run migration verification.

**Expected result**

* Source and destination match according to the implemented verification policy.
* Verification status is successful.

**Result:** NOT TESTED

---

## M3-VER-02 – Missing destination file

**Test**

Delete a migrated destination file before verification.

**Expected result**

* Verification detects the missing file.
* Migration is not considered fully verified.
* Missing file is identifiable.

**Result:** NOT TESTED

---

## M3-VER-03 – Modified destination file

**Test**

Modify a destination file after migration.

**Expected result**

* Modification is detected where covered by the implemented verification method.
* Verification reports the mismatch.

**Result:** NOT TESTED

---

## M3-VER-04 – File-size mismatch

**Test**

Change the size of a destination file.

**Expected result**

* Size mismatch is detected.
* Affected file is identified.
* Verification fails or warns according to policy.

**Result:** NOT TESTED

---

## M3-VER-05 – Hash mismatch

**Test**

Modify destination file content while preserving its size where possible.

Run hash verification when supported/enabled.

**Expected result**

* Hash comparison identifies different content.
* File is reported as mismatched.

If hash verification is not implemented or optional functionality is disabled, record this testcase as `N/A` and document the limitation.

**Result:** NOT TESTED

---

# 12. Security validation

## M3-SEC-01 – No global Windows security weakening

Verify that ProfMig does not:

* Disable UAC
* Disable Windows security services
* Disable ACL enforcement
* Modify global security policy unnecessarily
* Disable security controls to complete a migration

**Expected result:** PASS

**Result:** NOT TESTED

---

## M3-SEC-02 – No Everyone Full Control

Inspect destination ACLs after permission repair.

**Expected result**

ProfMig does not grant broad `Everyone: Full Control` permissions.

**Result:** NOT TESTED

---

## M3-SEC-03 – Windows access controls are respected

**Expected result**

ProfMig handles access failures through validation, classification, logging and recovery.

It must not attempt to bypass Windows access controls through unsafe global configuration changes.

**Result:** NOT TESTED

---

## M3-SEC-04 – Credentials are not exposed

Inspect:

* Console output
* ProfMig logs
* Migration reports
* Error details

**Expected result**

No passwords, authentication secrets, tokens or other credentials are exposed.

**Result:** NOT TESTED

---

## M3-SEC-05 – No credential decryption

**Expected result**

ProfMig does not attempt to decrypt or extract stored user credentials.

**Result:** NOT TESTED

---

## M3-SEC-06 – Source data remains unchanged

Compare selected source data before and after migration.

**Expected result**

* Source files are not deleted.
* Source files are not modified as part of migration.
* Source ACLs are not unexpectedly changed.

**Result:** NOT TESTED

---

## M3-SEC-07 – Security failures are visible

Trigger an access or permission related failure.

**Expected result**

* Security-related failure is logged.
* Failure appears in reporting where applicable.
* Failure is not silently ignored.
* Final migration status accurately reflects the condition.

**Result:** NOT TESTED

---

# 13. Logging validation

## M3-LOG-01 – Successful operation logging

Verify that normal migration activity produces the expected logging.

**Result:** NOT TESTED

---

## M3-LOG-02 – Warning logging

Trigger a warning condition.

**Expected result**

Warning is identifiable in the log with sufficient context.

**Result:** NOT TESTED

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

**Result:** NOT TESTED

---

## M3-LOG-04 – Critical failure logging

Trigger a critical validation or migration failure.

**Expected result**

Critical condition is clearly visible and traceable.

**Result:** NOT TESTED

---

## M3-LOG-05 – Sensitive information

Review generated logs.

**Expected result**

Logs contain sufficient diagnostic information without exposing credentials or secrets.

**Result:** NOT TESTED

---

# 14. Reporting validation

## M3-RPT-01 – Successful migration report

**Expected result**

Report correctly represents a successful migration.

**Result:** NOT TESTED

---

## M3-RPT-02 – Partial migration report

**Expected result**

Successful and failed items are distinguishable.

**Result:** NOT TESTED

---

## M3-RPT-03 – Failed migration report

**Expected result**

Critical failure is visible and the migration is not represented as successful.

**Result:** NOT TESTED

---

## M3-RPT-04 – Verification result

**Expected result**

Migration verification result is represented accurately in reporting.

**Result:** NOT TESTED

---

# 15. Defect handling

Any defect discovered during Sprint 3.8 must be evaluated for severity.

Recommended classifications:

| Severity | Description                                                            | M3 impact                                        |
| -------- | ---------------------------------------------------------------------- | ------------------------------------------------ |
| Critical | Unsafe migration, data integrity/security risk or uncontrolled failure | Must be fixed                                    |
| High     | Major functionality does not operate as designed                       | Fix before completion unless explicitly accepted |
| Medium   | Functional problem with acceptable workaround                          | May become known limitation                      |
| Low      | Cosmetic, reporting or minor usability issue                           | May be deferred                                  |

Each relevant defect must be registered as a separate GitHub issue.

The issue should contain:

* Testcase ID
* Description
* Reproduction steps
* Expected result
* Actual result
* Relevant logs
* Severity
* Proposed resolution where known

After resolving a defect, the original testcase must be executed again.

---

# 16. Known limitations

Any behaviour discovered during testing that is accepted but not resolved must be documented here.

| ID | Limitation                | Impact | Workaround | GitHub issue |
| -- | ------------------------- | ------ | ---------- | ------------ |
| -  | None currently documented | -      | -          | -            |

---

# 17. Test execution summary

| Area                     |  Total |  Pass |  Fail | Blocked |   N/A |
| ------------------------ | -----: | ----: | ----: | ------: | ----: |
| Profile validation       |      5 |     0 |     0 |       0 |     0 |
| Privileges               |      4 |     0 |     0 |       0 |     0 |
| Storage                  |      4 |     0 |     0 |       0 |     0 |
| File handling            |      7 |     0 |     0 |       0 |     0 |
| Permissions / ACL        |      5 |     0 |     0 |       0 |     0 |
| Recovery                 |      5 |     0 |     0 |       0 |     0 |
| Integrity / verification |      5 |     0 |     0 |       0 |     0 |
| Security                 |      7 |     0 |     0 |       0 |     0 |
| Logging                  |      5 |     0 |     0 |       0 |     0 |
| Reporting                |      4 |     0 |     0 |       0 |     0 |
| **Total**                | **51** | **0** | **0** |   **0** | **0** |

---

# 18. Milestone 3 acceptance criteria

M3 can be approved when:

* [ ] Critical validation failures prevent unsafe migration.
* [ ] Non-critical errors are handled predictably.
* [ ] Insufficient disk space is detected.
* [ ] Locked files do not cause uncontrolled failure.
* [ ] Destination permissions are correct.
* [ ] Migration failures are recoverable where designed.
* [ ] Migration integrity can be verified.
* [ ] Security controls are not bypassed.
* [ ] Logging correctly represents warnings and failures.
* [ ] Reporting correctly represents migration outcome.
* [ ] All critical defects discovered during M3 testing are resolved.
* [ ] Resolved critical defects have been retested.
* [ ] Known limitations are documented.
* [ ] No unresolved critical defects remain.

---

# 19. Final M3 validation

**Sprint:** 3.8 – Security & Reliability Validation
**Milestone:** M3 – Reliability & Security

**Overall result:** NOT TESTED

**Open critical defects:** TBD
**Open high defects:** TBD
**Known limitations:** TBD

## Final conclusion

Milestone 3 – Reliability & Security can only be marked complete after all required test scenarios have been executed, all acceptance criteria have been evaluated and no unresolved critical defects remain.

**M3 status: NOT YET APPROVED**
