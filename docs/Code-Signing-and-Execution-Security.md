# Code Signing and Execution Security

## Overview

ProfMig uses Authenticode code signing and SHA-256 package integrity
verification to protect release packages against unauthorized modification.

Code signing is applied only to generated release packages.

Development source code remains unsigned so that contributors can develop,
test, commit and review changes without access to the release signing key.

## Security model

The ProfMig release security model consists of two complementary controls:

1. Authenticode signatures for executable PowerShell code.
2. A SHA-256 manifest covering the complete runtime package.

Authenticode provides publisher identity and integrity protection for
PowerShell scripts and modules.

The SHA-256 manifest provides package-level integrity and completeness
validation for executable and non-executable release content.

## Development and release separation

The ProfMig source repository is not signed during normal development.

Developers do not require access to the release signing certificate or
private key.

The release process is:

1. Develop and test unsigned source code.
2. Create the runtime package.
3. Sign executable PowerShell files in the generated package.
4. Validate all Authenticode signatures.
5. Generate the SHA-256 release manifest.
6. Validate the complete release package.
7. Publish the validated package.

Signing must occur after package creation because Authenticode modifies the
signed files.

The SHA-256 manifest must be generated after Authenticode signing because
the manifest records the final signed file hashes.

## Runtime package signing

The signing tool is:

    build\Sign-ProfMigPackage.ps1

It signs executable PowerShell files in the generated runtime package:

- .ps1
- .psm1

The signing certificate is selected explicitly using its certificate
thumbprint.

Example:

    .\build\Sign-ProfMigPackage.ps1 `
        -CertificateThumbprint "<CODE-SIGNING-CERTIFICATE-THUMBPRINT>"

The certificate must:

- Be available through the Windows certificate store.
- Have an accessible private key.
- Contain the Code Signing EKU.
- Support SHA-256 Authenticode signing.

Certificate thumbprints are not hard-coded in the ProfMig repository.

## Hardware-backed signing

Sprint 5.7 was validated using a hardware-backed private key stored on a
YubiKey PIV device.

The private signing key remains on the hardware token and is not exported
into the ProfMig repository or release package.

Development and test signing does not imply that the same certificate or
token configuration must be used for production releases.

For production release signing, a dedicated signing credential is
recommended.

Production signing policy should require appropriate operator
authentication and physical possession of the signing device.

## Authenticode validation

The validation tool is:

    build\Test-ProfMigSignatures.ps1

All .ps1 and .psm1 files in the runtime package must have an Authenticode
status of Valid.

A single unsigned, invalid or modified executable PowerShell file causes
release validation to fail.

Sprint 5.7 validation covered 23 executable PowerShell files.

A controlled modification of a signed module resulted in:

    HashMismatch

The package was correctly rejected.

## SHA-256 release manifest

The manifest generator is:

    build\New-ProfMigHashManifest.ps1

It creates:

    ProfMig-SHA256.txt

The manifest is generated from the final signed runtime package.

Runtime output directories such as Logs and Reports are excluded.

The manifest covers all distributed runtime files, including:

- PowerShell scripts.
- PowerShell modules.
- PowerShell data files.
- Migration profiles.
- Application definitions.
- Start-ProfMig.bat.
- LICENSE.
- ProfMig.Build.psd1.

Sprint 5.7 validation covered 30 release files.

## SHA-256 manifest validation

The validation tool is:

    build\Test-ProfMigHashManifest.ps1

Validation fails when:

- An existing release file has been modified.
- An expected release file is missing.
- An unexpected file has been added.

This protects both file integrity and package completeness.

## ExecutionPolicy validation

Sprint 5.7 was tested using PowerShell ExecutionPolicy AllSigned at Process
scope.

The tests confirmed:

- Unsigned PowerShell code was blocked.
- Tampered signed PowerShell code was blocked.
- Valid signed ProfMig code was permitted after publisher confirmation.

AllSigned was used only as a controlled security test.

ProfMig does not require developers to configure their development
workstations with AllSigned.

ExecutionPolicy requirements for production environments remain an
administrator deployment decision.

## Regression testing

The Sprint 5.7 regression test is:

    tests\Test-ProfMigCodeSigning.ps1

The regression test does not require access to the signing private key.

It operates against an already signed release package and uses isolated
temporary copies for destructive tests.

The following tests are performed:

1. Valid Authenticode package accepted.
2. Tampered Authenticode file rejected.
3. Valid SHA-256 manifest accepted.
4. Modified package file detected.
5. Missing package file detected.
6. Unexpected package file detected.

Sprint 5.7 result:

    Passed: 6
    Failed: 0

## Private key protection

Private signing material must never be committed to the ProfMig repository.

This includes:

- Private keys.
- PFX or P12 files containing private keys.
- Hardware-token PINs.
- PIV management keys.
- Signing secrets or passwords.

The repository must contain only tooling and documentation required to use
an externally managed signing credential.

## Production considerations

The Sprint 5.7 implementation establishes the signing and verification
architecture.

Before production release signing, the production signing credential and
operational policy must be defined.

Recommended controls include:

- Dedicated release signing credential.
- Hardware-backed private key.
- Restricted access to the signing credential.
- Strong operator authentication.
- Physical confirmation where supported.
- Documented certificate renewal procedure.
- Documented certificate revocation procedure.
- Separation between development and release signing.
- Verification before publication.

## Sprint 5.7 validation result

The implementation successfully demonstrated:

- Hardware-backed Authenticode signing.
- SHA-256 Authenticode signatures.
- 23/23 valid executable PowerShell signatures.
- Detection of signed-code modification.
- AllSigned execution-policy enforcement.
- 30/30 valid SHA-256 release hashes.
- Detection of modified package content.
- Detection of missing package content.
- Detection of unexpected package content.
- 6/6 automated security regression tests.

The development workflow remains independent of the release signing
credential.