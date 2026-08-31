# ============================================================================
# ProfMig - Milestone 3 Security Regression Tests
# ============================================================================
# Compatible with Pester 3.4
# ============================================================================

$M3Root = Split-Path -Parent $PSScriptRoot
$HelperPath = Join-Path $M3Root 'TestHelpers.psm1'

Import-Module $HelperPath -Force

$RepositoryRoot = Get-ProfMigTestRepositoryRoot
$ExclusionModule = Get-ProfMigTestModulePath `
    -ModuleName 'ProfMig.Exclusions'

Remove-Module ProfMig.Exclusions `
    -Force `
    -ErrorAction SilentlyContinue

Import-Module $ExclusionModule -Force

Initialize-ProfMigDefaultExclusions


Describe 'M3 - Security Validation' {

    It 'M3-SEC-05 prevents migration of credential stores and contains no credential decryption code' {

        # ------------------------------------------------------------
        # Mandatory runtime security exclusions
        # ------------------------------------------------------------

        $SecurityCases = @(
            @{
                Path   = 'AppData\Roaming\Microsoft\Credentials\credential.bin'
                RuleId = 'SEC-001'
            },
            @{
                Path   = 'AppData\Local\Microsoft\Credentials\credential.bin'
                RuleId = 'SEC-002'
            },
            @{
                Path   = 'AppData\Roaming\Microsoft\Protect\S-1-5-21\masterkey'
                RuleId = 'SEC-003'
            },
            @{
                Path   = 'AppData\Local\Microsoft\Vault\vault.dat'
                RuleId = 'SEC-004'
            },
            @{
                Path   = 'AppData\Local\Google\Chrome\User Data\Default\Login Data'
                RuleId = 'SEC-005'
            },
            @{
                Path   = 'AppData\Local\Microsoft\Edge\User Data\Default\Login Data'
                RuleId = 'SEC-005'
            },
            @{
                Path   = 'AppData\Local\Microsoft\Outlook\mailbox.ost'
                RuleId = 'SEC-006'
            }
        )

        foreach ($Case in $SecurityCases) {

            $Result = Test-ProfMigExclusion `
                -RelativePath $Case.Path

            $Result.Excluded |
                Should Be $true

            $Result.Mandatory |
                Should Be $true

            $Result.Category |
                Should Be 'Security'

            $Result.RuleId |
                Should Be $Case.RuleId
        }


        # ------------------------------------------------------------
        # Verify mandatory security rules themselves
        # ------------------------------------------------------------

        $SecurityRules = @(
            Get-ProfMigExclusionRules |
                Where-Object {
                    $_.Category -eq 'Security'
                }
        )

        $SecurityRules.Count |
            Should BeGreaterThan 5

        foreach ($RuleId in @(
            'SEC-001',
            'SEC-002',
            'SEC-003',
            'SEC-004',
            'SEC-005',
            'SEC-006'
        )) {

            $MatchingRule = @(
                $SecurityRules |
                    Where-Object {
                        $_.RuleId -eq $RuleId
                    }
            )

            $MatchingRule.Count |
                Should Be 1

            $MatchingRule[0].Mandatory |
                Should Be $true
        }


        # ------------------------------------------------------------
        # Static scan for credential extraction/decryption mechanisms
        # ------------------------------------------------------------

        $ForbiddenPatterns = @(
            'CryptUnprotectData',
            'ProtectedData\s*::\s*Unprotect',
            'CredEnumerate',
            'VaultEnumerate',
            'PasswordVault'
        )

        $SourceFiles = @(
            Get-ChildItem `
                -Path (Join-Path $RepositoryRoot 'src') `
                -Recurse `
                -File `
                -Include *.ps1,*.psm1
        )

        $Findings = @()

        foreach ($SourceFile in $SourceFiles) {

            $SourceText = Get-Content `
                -LiteralPath $SourceFile.FullName `
                -Raw

            foreach ($Pattern in $ForbiddenPatterns) {

                if ($SourceText -match $Pattern) {

                    $Findings += [PSCustomObject]@{
                        File    = $SourceFile.FullName
                        Pattern = $Pattern
                    }
                }
            }
        }

        $Findings.Count |
            Should Be 0
    }

    It 'M3-SEC-03 respects Windows access controls and does not alter the source ACL' {

        $CopyEngineModule = Get-ProfMigTestModulePath `
            -ModuleName 'ProfMig.CopyEngine'

        Remove-Module ProfMig.CopyEngine `
            -Force `
            -ErrorAction SilentlyContinue

        Import-Module $CopyEngineModule -Force

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'SEC-03'

        $SourceFile = Join-Path $TestRoot 'Protected.txt'
        $DestinationFile = Join-Path $TestRoot 'Destination\Protected.txt'

        Set-Content `
            -LiteralPath $SourceFile `
            -Value 'ProfMig SEC-03 controlled source data' `
            -Encoding UTF8

        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $CurrentUserSid = $Identity.User

        $DenyRule = New-Object `
            System.Security.AccessControl.FileSystemAccessRule(
                $CurrentUserSid,
                [System.Security.AccessControl.FileSystemRights]::ReadData,
                [System.Security.AccessControl.AccessControlType]::Deny
            )

        $Acl = Get-Acl -LiteralPath $SourceFile
        $Acl.AddAccessRule($DenyRule)
        Set-Acl -LiteralPath $SourceFile -AclObject $Acl

        try {

            $AclBefore = (
                Get-Acl -LiteralPath $SourceFile
            ).Sddl

            $Result = Invoke-ProfMigFileCopy `
                -Component 'SecurityTest' `
                -SourceFile $SourceFile `
                -DestinationFile $DestinationFile

            $AclAfter = (
                Get-Acl -LiteralPath $SourceFile
            ).Sddl

            $Result.FilesSelected |
                Should Be 1

            $Result.FilesCopied |
                Should Be 0

            $Result.FilesFailed |
                Should Be 1

            $Result.Status |
                Should Be 'CompletedWithErrors'

            @($Result.Errors).Count |
                Should Be 1

            $Result.Errors[0].Category |
                Should Be 'PermissionError'

            $Result.Errors[0].Reason |
                Should Be 'AccessDenied'

            (Test-Path -LiteralPath $DestinationFile) |
                Should Be $false

            $AclAfter |
                Should Be $AclBefore
        }
        finally {

            if (Test-Path -LiteralPath $SourceFile) {

                $CleanupAcl = Get-Acl -LiteralPath $SourceFile
                $CleanupAcl.RemoveAccessRuleSpecific($DenyRule)
                Set-Acl `
                    -LiteralPath $SourceFile `
                    -AclObject $CleanupAcl
            }

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }

    It 'M3-SEC-06 leaves source data and ACL unchanged during migration' {

        $CopyEngineModule = Get-ProfMigTestModulePath `
            -ModuleName 'ProfMig.CopyEngine'

        Remove-Module ProfMig.CopyEngine `
            -Force `
            -ErrorAction SilentlyContinue

        Import-Module $CopyEngineModule -Force

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'SEC-06'

        $SourceFile = Join-Path $TestRoot 'Source.txt'
        $DestinationFile = Join-Path $TestRoot 'Destination\Source.txt'

        try {

            Set-Content `
                -LiteralPath $SourceFile `
                -Value 'ProfMig SEC-06 controlled source data' `
                -Encoding UTF8

            $SourceBefore = Get-Item `
                -LiteralPath $SourceFile

            $SizeBefore = [int64]$SourceBefore.Length

            $HashBefore = (
                Get-FileHash `
                    -LiteralPath $SourceFile `
                    -Algorithm SHA256
            ).Hash

            $LastWriteBefore = $SourceBefore.LastWriteTimeUtc

            $AclBefore = (
                Get-Acl -LiteralPath $SourceFile
            ).Sddl


            $Result = Invoke-ProfMigFileCopy `
                -Component 'SecurityTest' `
                -SourceFile $SourceFile `
                -DestinationFile $DestinationFile `
                -VerificationLevel Hash `
                -HashAlgorithm SHA256


            $SourceAfter = Get-Item `
                -LiteralPath $SourceFile

            $SizeAfter = [int64]$SourceAfter.Length

            $HashAfter = (
                Get-FileHash `
                    -LiteralPath $SourceFile `
                    -Algorithm SHA256
            ).Hash

            $LastWriteAfter = $SourceAfter.LastWriteTimeUtc

            $AclAfter = (
                Get-Acl -LiteralPath $SourceFile
            ).Sddl


            # Source still exists and is unchanged.

            (Test-Path -LiteralPath $SourceFile) |
                Should Be $true

            $SizeAfter |
                Should Be $SizeBefore

            $HashAfter |
                Should Be $HashBefore

            $LastWriteAfter |
                Should Be $LastWriteBefore

            $AclAfter |
                Should Be $AclBefore


            # Copy completed successfully.

            $Result.FilesSelected |
                Should Be 1

            $Result.FilesCopied |
                Should Be 1

            $Result.FilesFailed |
                Should Be 0

            $Result.Status |
                Should Be 'Success'

            $Result.FilesVerified |
                Should Be 1

            $Result.VerificationFailures |
                Should Be 0

            $Result.VerificationStatus |
                Should Be 'Success'


            # Destination exists and contains identical data.

            (Test-Path -LiteralPath $DestinationFile) |
                Should Be $true

            $DestinationItem = Get-Item `
                -LiteralPath $DestinationFile

            [int64]$DestinationItem.Length |
                Should Be $SizeBefore

            $DestinationHash = (
                Get-FileHash `
                    -LiteralPath $DestinationFile `
                    -Algorithm SHA256
            ).Hash

            $DestinationHash |
                Should Be $HashBefore
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }

    It 'M3-SEC-07 exposes security failures in migration status and reporting' {

        $CopyEngineModule = Get-ProfMigTestModulePath `
            -ModuleName 'ProfMig.CopyEngine'

        $ReportingModule = Get-ProfMigTestModulePath `
            -ModuleName 'ProfMig.Reporting'

        $LoggingModule = Get-ProfMigTestModulePath `
            -ModuleName 'ProfMig.Logging'

        Remove-Module ProfMig.CopyEngine `
            -Force `
            -ErrorAction SilentlyContinue

        Remove-Module ProfMig.Reporting `
            -Force `
            -ErrorAction SilentlyContinue

        Remove-Module ProfMig.Logging `
            -Force `
            -ErrorAction SilentlyContinue

        Import-Module $LoggingModule -Force
        Import-Module $CopyEngineModule -Force
        Import-Module $ReportingModule -Force

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'SEC-07'

        $SourceFile = Join-Path $TestRoot 'Protected.txt'

        $DestinationFile = Join-Path `
            $TestRoot `
            'Destination\Protected.txt'

        $ReportFolder = Join-Path `
            $TestRoot `
            'Reports'

        Set-Content `
            -LiteralPath $SourceFile `
            -Value 'ProfMig SEC-07 controlled source data' `
            -Encoding UTF8

        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $CurrentUserSid = $Identity.User

        $DenyRule = New-Object `
            System.Security.AccessControl.FileSystemAccessRule(
                $CurrentUserSid,
                [System.Security.AccessControl.FileSystemRights]::ReadData,
                [System.Security.AccessControl.AccessControlType]::Deny
            )

        $Acl = Get-Acl -LiteralPath $SourceFile
        $Acl.AddAccessRule($DenyRule)
        Set-Acl -LiteralPath $SourceFile -AclObject $Acl

        try {

            # --------------------------------------------------------
            # Trigger a real Windows access-denied copy failure
            # --------------------------------------------------------

            $FileResult = Invoke-ProfMigFileCopy `
                -Component 'SecurityTest' `
                -SourceFile $SourceFile `
                -DestinationFile $DestinationFile


            $FileResult.FilesSelected |
                Should Be 1

            $FileResult.FilesCopied |
                Should Be 0

            $FileResult.FilesFailed |
                Should Be 1

            $FileResult.Status |
                Should Be 'CompletedWithErrors'

            @($FileResult.Errors).Count |
                Should Be 1

            $FileResult.Errors[0].Category |
                Should Be 'PermissionError'

            $FileResult.Errors[0].Severity |
                Should Be 'Error'

            $FileResult.Errors[0].Reason |
                Should Be 'AccessDenied'

            (Test-Path -LiteralPath $DestinationFile) |
                Should Be $false


            # --------------------------------------------------------
            # Build the aggregate CopyResult contract expected by
            # ConvertTo-ProfMigMigrationResult.
            # --------------------------------------------------------

            $CopyResult = [PSCustomObject]@{
                SourceProfile      = $TestRoot
                DestinationProfile = (
                    Split-Path -Parent $DestinationFile
                )
                StartedAt          = $FileResult.StartedAt
                CompletedAt        = $FileResult.CompletedAt
                Duration           = $FileResult.Duration
                Status             = $FileResult.Status

                Components = @(
                    [PSCustomObject]@{
                        Component = 'SecurityTest'
                        Result    = $FileResult
                    }
                )

                Totals = [PSCustomObject]@{
                    FilesSelected       = [int64]$FileResult.FilesSelected
                    FilesCopied         = [int64]$FileResult.FilesCopied
                    FilesSkipped        = [int64]$FileResult.FilesSkipped
                    FilesExcluded       = [int64]$FileResult.FilesExcluded
                    FilesFailed         = [int64]$FileResult.FilesFailed
                    BytesCopied         = [int64]$FileResult.BytesCopied
                    FilesVerified       = [int64]$FileResult.FilesVerified
                    BytesVerified       = [int64]$FileResult.BytesVerified
                    VerificationFailures = [int64]$FileResult.VerificationFailures
                    VerificationLevel   = 'Standard'
                    HashAlgorithm       = 'SHA256'
                }

                SkippedItems  = @($FileResult.SkippedItems)
                ExcludedItems = @($FileResult.ExcludedItems)
                Errors        = @($FileResult.Errors)

                VerificationResults = @(
                    $FileResult.VerificationResults
                )
            }


            # --------------------------------------------------------
            # Convert to the ProfMig reporting model
            # --------------------------------------------------------

            $MigrationResult = ConvertTo-ProfMigMigrationResult `
                -CopyResult $CopyResult `
                -ProfMigVersion 'M3-Regression-Test'


            $MigrationResult.FilesFailed |
                Should Be 1

            $MigrationResult.Status |
                Should Be 'Failed'

            @($MigrationResult.FailedItems).Count |
                Should BeGreaterThan 0

            $MigrationResult.FailedItems[0].Category |
                Should Be 'PermissionError'

            $MigrationResult.FailedItems[0].Severity |
                Should Be 'Error'

            $MigrationResult.FailedItems[0].Reason |
                Should Be 'AccessDenied'


            # --------------------------------------------------------
            # Generate and inspect the human-readable report
            # --------------------------------------------------------

            $ReportFile = New-ProfMigMigrationReport `
                -MigrationResult $MigrationResult `
                -ReportFolder $ReportFolder

            [string]::IsNullOrWhiteSpace($ReportFile) |
                Should Be $false

            (Test-Path -LiteralPath $ReportFile) |
                Should Be $true

            $ReportText = Get-Content `
                -LiteralPath $ReportFile `
                -Raw

            ($ReportText -match 'PermissionError') |
                Should Be $true

            ($ReportText -match 'AccessDenied') |
                Should Be $true

            ($ReportText -match 'Files failed\s*:\s*1') |
                Should Be $true

            ($ReportText -match '(?ms)Overall result\s*=+\s*Failed') |
                Should Be $true
        }
        finally {

            if (Test-Path -LiteralPath $SourceFile) {

                $CleanupAcl = Get-Acl `
                    -LiteralPath $SourceFile

                $CleanupAcl.RemoveAccessRuleSpecific(
                    $DenyRule
                )

                Set-Acl `
                    -LiteralPath $SourceFile `
                    -AclObject $CleanupAcl
            }

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }
}





