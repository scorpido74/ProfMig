Migration Verification and Data Integrity

Sprint

3.7 – Migration Verification & Data Integrity

Objective

Sprint 3.7 adds migration verification to ProfMig so that a successful copy
operation is not automatically treated as a successful migration.

ProfMig verifies that data reported as copied is present at the destination and
matches the expected source data. Verification results are represented by
structured objects and are included in migration totals and reporting.

The implementation is designed to provide useful integrity checks during normal
migrations without making large migrations unnecessarily slow.

Verification model

ProfMig supports two verification levels:

Standard

Standard is the default verification level.

For each copied file ProfMig verifies:

the source file still exists when verification is performed;

the destination file exists;

the destination file size matches the source file size.

No file hashes are calculated in this mode.

This provides practical verification for normal migrations while avoiding the
additional I/O and CPU cost of hashing every migrated file.

Hash

Hash performs the Standard checks and additionally calculates a cryptographic
hash for the source and destination file.

The hashes must match for the file to be considered verified.

Hash verification is optional because hashing every file can significantly
increase migration time, particularly for large profiles or slower storage.

SHA256 is the configured default algorithm.

Configuration

Verification is configured in src/Config.psd1.

Example:

Verification = @{
    Level         = 'Standard'
    HashAlgorithm = 'SHA256'
}

Supported verification levels:

Standard

Hash

The configured hash algorithm is only used when the verification level requires
hash verification.

The implementation validates verification configuration before using it. An
invalid verification level or unsupported hash algorithm is treated as a
configuration error rather than silently falling back to weaker verification.

Verification module

Verification functionality is implemented in:

src/Modules/ProfMig.Verification.psm1

The module provides the verification framework, structured verification
results, verification summaries, file verification and optional hash
verification.

Verification result

Individual file verification produces a structured
ProfMig.VerificationResult object.

The object contains information such as:

Component

SourceFile

DestinationFile

VerificationLevel

SourceExists

DestinationExists

SourceSize

DestinationSize

SizeMatch

HashAlgorithm

SourceHash

DestinationHash

HashMatch

Status

Reason

Verified

This allows CopyEngine and Reporting to consume verification information without
parsing text output.

Verification summary

Verification totals are represented by a structured
ProfMig.VerificationSummary object.

Summary information includes:

FilesSelected

FilesCopied

FilesVerified

FilesSkipped

FilesFailed

BytesSelected

BytesCopied

BytesVerified

VerificationFailures

FileCountMatch

ByteCountMatch

Verified

Status

Verification failures therefore remain distinct from copy failures.

A file may have been copied successfully but still fail verification.

File verification

Destination existence

After a file is copied, ProfMig verifies that the expected destination file
exists.

If it does not exist, verification fails with:

DestinationMissing

The file is not silently considered migrated.

File size

When source and destination exist, ProfMig compares their file sizes.

A difference produces:

SizeMismatch

This detects incomplete or unexpectedly modified destination files even when
the original copy operation itself did not report an error.

Hash verification

When verification level Hash is enabled, ProfMig calculates hashes for both
source and destination.

Different file contents with identical file sizes are therefore detectable.

A mismatch produces:

HashMismatch

A file is only verified successfully when the required checks for the selected
verification level pass.

CopyEngine integration

Verification is integrated into:

src/Modules/ProfMig.CopyEngine.psm1

After a successful file copy, CopyEngine performs verification and stores the
result in VerificationResult.

Component-level processing collects the individual verification results and
calculates verification totals.

Component results expose:

FilesVerified

BytesVerified

VerificationFailures

VerificationStatus

VerificationResults

Verification failures affect component status.

For example, a component can have:

FilesCopied          : 3
FilesFailed          : 0
FilesVerified        : 2
VerificationFailures : 1
VerificationStatus   : Failed
Status               : CompletedWithErrors

This distinction is intentional.

FilesFailed = 0 means the copy operations did not fail. It does not prove that
the copied data passed integrity verification.

Configuration integration

Invoke-ProfMigCopy reads the verification configuration and passes it through
the migration pipeline.

The effective flow is:

Config.psd1
    |
    v
Invoke-ProfMigCopy
    |
    v
Copy-ProfMigComponent
    |
    v
Copy-ProfMigSingleFile
    |
    v
Test-ProfMigFileVerification

Migration-level results also expose:

FilesVerified

BytesVerified

VerificationFailures

VerificationLevel

HashAlgorithm

This provides both evidence of the verification performed and the configuration
under which the migration ran.

Migration totals

Sprint 3.7 adds verification-aware migration totals.

Relevant totals include:

Files selected

Files copied

Files verified

Files skipped

Files failed

Bytes selected

Bytes copied

Bytes verified

Verification failures

Copy statistics and verification statistics are deliberately separate.

This makes cases such as the following visible:

FilesCopied          : 1
FilesFailed          : 0
FilesVerified        : 0
VerificationFailures : 1

Such a migration must not be reported as successful.

Reporting integration

Verification is integrated into:

src/Modules/ProfMig.Reporting.psm1

The migration report includes verification information at migration and
component level.

The report contains:

Overall migration statistics

Including:

Files verified

Verification failures

Bytes verified

Verification configuration

Including:

Verification level

Hash algorithm

Verification by component

For each migrated component the report includes:

Files verified

Bytes verified

Verification failures

Verification status

Verification failures

Individual failed verification items are reported with information such as:

Component

Source

Destination

Verification level

Reason

Source size

Destination size

Size match

Hash algorithm

Hash match

Verification failures are also included in the reporting error information.

Migration status

Migration success is not based only on copy execution.

A verification failure causes the migration result to fail even when the copy
operation itself reported no file failures.

This scenario was explicitly tested:

FilesCopied          : 1
FilesFailed          : 0
FilesVerified        : 0
BytesCopied          : 100
BytesVerified        : 0
VerificationFailures : 1
Status               : Failed

The generated migration report also showed:

Verification status   : Failed

and:

Overall result
============================================================

Failed

This satisfies the central requirement of sprint 3.7: successful execution of a
copy operation alone is not sufficient evidence of a successful migration.

Verification failure reasons tested

DestinationMissing

Test:

Create source file.

Copy it to the destination.

Remove the destination file.

Run Standard verification.

Result:

DestinationExists : False
Status            : Failed
Reason            : DestinationMissing
Verified          : False

SizeMismatch

Test:

Create source file.

Copy it to the destination.

Replace destination content with shorter content.

Run Standard verification.

Result:

SizeMatch : False
Status    : Failed
Reason    : SizeMismatch
Verified  : False

HashMismatch

A test used two binary files with the same size but different contents.

Standard verification succeeded because both files existed and had the same
size.

Hash verification using SHA256 produced different source and destination hashes
and returned:

HashMatch : False
Status    : Failed
Reason    : HashMismatch
Verified  : False

After replacing the destination with an exact copy of the source, SHA256
verification returned:

HashMatch : True
Status    : Success
Reason    : Verified
Verified  : True

This confirms that optional hash verification detects content differences that
existence and size checks cannot detect.

Component verification test

A component integration test copied three files.

Successful result:

FilesSelected        : 3
FilesCopied          : 3
FilesVerified        : 3
FilesFailed          : 0
BytesCopied          : 56
BytesVerified        : 56
VerificationFailures : 0
VerificationStatus   : Success
Status               : Success

A controlled negative verification test returned one SizeMismatch.

Result:

FilesSelected        : 3
FilesCopied          : 3
FilesVerified        : 2
FilesFailed          : 0
BytesCopied          : 56
BytesVerified        : 36
VerificationFailures : 1
VerificationStatus   : Failed
Status               : CompletedWithErrors

This confirms that CopyEngine component status depends on verification results
and not only on successful copy execution.

Verification level tests

Standard

The CopyEngine was tested using:

VerificationLevel : Standard

Two files were copied and verified.

Result:

FilesCopied          : 2
FilesVerified        : 2
BytesCopied          : 50
BytesVerified        : 50
VerificationFailures : 0
VerificationStatus   : Success
Status               : Success

Individual results showed:

VerificationLevel : Standard
SizeMatch         : True
Status            : Success
Reason            : Verified

No hashes were calculated.

Hash

The same CopyEngine path was tested with:

VerificationLevel : Hash
HashAlgorithm     : SHA256

Result:

FilesCopied          : 2
FilesVerified        : 2
BytesCopied          : 50
BytesVerified        : 50
VerificationFailures : 0
VerificationStatus   : Success
Status               : Success

Individual results showed:

VerificationLevel : Hash
HashAlgorithm     : SHA256
SizeMatch         : True
HashMatch         : True
Status            : Success
Reason            : Verified

Reporting tests

Reporting was tested with structured success and failure scenarios.

Successful verification

Input:

FilesCopied          : 1
FilesVerified        : 1
BytesCopied          : 100
BytesVerified        : 100
VerificationFailures : 0
VerificationLevel    : Standard
HashAlgorithm        : SHA256

Result:

Status : Success

The generated report contained the migration totals, verification
configuration, component verification status and no verification failures.

Failed verification

A copied file was represented with:

SourceSize      : 100
DestinationSize : 50
SizeMatch       : False
Reason          : SizeMismatch
Verified        : False

Copy statistics still reported:

FilesCopied : 1
FilesFailed : 0

The resulting migration status was:

Status : Failed

The report listed the failed file under Verification failures and included:

Component        : Documents
Source           : C:\Source\Documents\Bad.txt
Destination      : C:\Destination\Documents\Bad.txt
Level            : Standard
Reason           : SizeMismatch
Source size      : 100
Destination size : 50
Size match       : False

Performance considerations

Hash verification is intentionally optional.

The default Standard mode performs lightweight checks based on destination
existence and file size.

This avoids reading every source and destination file a second time solely to
calculate hashes during normal migrations.

Hash verification can be enabled when stronger integrity evidence is required.

This design keeps large migrations practical while allowing stronger
verification for selected environments or scenarios.

Source data safety

Verification performs read-only integrity checks against source data.

Verification must not modify source files.

The verification process reads source metadata and, when Hash mode is enabled,
reads file contents for hash calculation.

Destination data is also read for verification but is not altered by the
verification operation itself.

Acceptance criteria

Acceptance criterion

Result

ProfMig verifies copied data

Passed

Missing destination files are detected

Passed

File-size mismatches are detected

Passed

Migration totals are available

Passed

Verification failures appear in reporting

Passed

Optional stronger verification can be enabled

Passed

Migration success is based on verification results

Passed

Hash verification is configurable

Passed

Hash mismatch is detected

Passed

Verification uses structured objects

Passed

Verification does not modify source data

Passed by design and implementation

Normal migrations do not require hashing every file

Passed

Definition of Done

Sprint 3.7 is considered complete when ProfMig can verify migration results and
provide evidence that selected data was successfully transferred to the
destination.

The implementation now provides:

configurable Standard and Hash verification;

destination existence checks;

source/destination size comparison;

optional SHA256 hash comparison;

file and byte verification totals;

structured verification results;

component-level verification status;

migration-level verification totals;

reporting of verification failures;

migration failure when copied data does not pass verification.

The implemented positive and negative tests demonstrate that ProfMig no longer
treats a successful copy operation alone as proof of a successful migration.

Sprint 3.7 implementation commits

The implementation was developed incrementally on:

feature/sprint-3.7-migration-verification

Relevant commits:

ec19f87  feat: add migration verification framework
c2c6c8d  feat: verify migrated file existence and size
555cc29  feat: add migration verification totals
34d0231  feat: add optional hash verification
977387d  feat: integrate verification with copy engine
85ab410  feat: configure migration verification
18609b9  feat: integrate verification with reporting