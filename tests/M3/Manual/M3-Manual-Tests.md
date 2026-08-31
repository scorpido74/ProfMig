# ProfMig Milestone 3 – Manual and Hybrid Regression Tests

## Purpose

Most Milestone 3 security and reliability validation is covered by the
automated Pester regression suite in:

    tests\M3\Automated

Some validation scenarios depend on the Windows process context or on
machine-wide Windows security configuration. These tests intentionally
remain manual or hybrid and must not be considered covered solely by the
automated regression suite.

The authoritative original validation procedures and results remain
documented in:

    docs\M3-Security-Reliability-Test-Plan.md

---

## M3-PRIV-02 – Run without required privileges

**Classification:** Hybrid / manual execution required

### Purpose

Verify that ProfMig detects execution without the required administrative
privileges and prevents migration from starting.

### Why this remains manual/hybrid

The automated M3 regression suite is normally executed from an elevated
PowerShell session. A genuine non-elevated process context cannot therefore
be proven by the elevated Pester process itself.

The automated privilege tests validate the privilege-detection logic and
the elevated execution path, but this test requires a real non-elevated
ProfMig launch.

### Procedure

1. Open a normal PowerShell session without selecting **Run as administrator**.
2. Confirm that the session is not elevated.
3. Start ProfMig using its normal entry point.
4. Attempt to proceed with a migration.

### Expected result

- Missing administrative privileges are detected.
- Migration is blocked before copying data.
- A critical validation error is generated.
- The failure is logged.
- ProfMig does not terminate uncontrollably.

### Regression result

Record:

- Date:
- Tester:
- ProfMig version/commit:
- Result: PASS / FAIL / BLOCKED
- Evidence/notes:

---

## M3-SEC-01 – No global Windows security weakening

**Classification:** Hybrid / manual inspection required

### Purpose

Verify that ProfMig does not weaken machine-wide Windows security controls
as part of migration or recovery operations.

### Why this remains manual/hybrid

Individual ACL and security behaviours are covered by automated regression
tests. Machine-wide Windows security configuration, however, is broader
than the ProfMig process and should be validated against the actual test
system before and after migration.

### Procedure

Before running ProfMig, record the relevant Windows security state.

Run a representative ProfMig migration.

After migration, verify that ProfMig has not globally weakened Windows
security configuration.

At minimum verify:

- UAC has not been disabled or weakened.
- Windows security services have not been disabled by ProfMig.
- Windows Firewall configuration has not been globally disabled by ProfMig.
- ACL enforcement remains active.
- ProfMig has not introduced broad machine-wide permissions as a recovery
  mechanism.
- No global security policy has been changed to bypass an access failure.

### Expected result

- No global Windows security control is weakened.
- Security failures remain visible rather than being bypassed.
- Permission recovery remains scoped to the intended destination.
- No broad security workaround is introduced.

### Regression result

Record:

- Date:
- Tester:
- ProfMig version/commit:
- Result: PASS / FAIL / BLOCKED
- Evidence/notes:

---

## Automated coverage relationship

The automated M3 regression suite complements these manual/hybrid tests.

Current automated coverage includes validation of:

- elevated privilege detection;
- storage and profile validation;
- file access and failure handling;
- destination ACL validation and repair;
- structured recovery behaviour;
- migration verification and hashing;
- sensitive-data log redaction;
- reporting of structured failures;
- Windows source access-denied handling;
- mandatory credential-store exclusions;
- source data and source ACL preservation;
- visibility of security failures through the final migration report.

Run the automated regression suite with:

    & '.\tests\M3\Invoke-M3Tests.ps1'

A successful automated run must return exit code 0 with no failed,
pending or inconclusive tests.

Manual/hybrid PASS results do not replace automated regression results,
and automated PASS results do not replace the two manual/hybrid checks
defined in this document.
