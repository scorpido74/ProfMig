Set-StrictMode -Version Latest

$script:ExclusionRules = @()

function New-ProfMigExclusionRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RuleId,

        [Parameter(Mandatory)]
        [ValidateSet(
            'RelativePath',
            'FileName',
            'DirectoryName',
            'Extension'
        )]
        [string]$RuleType,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Category,

        [string]$Application,

        [string]$Reason,

        [switch]$Mandatory
    )

    [PSCustomObject]@{
        RuleId      = $RuleId
        RuleType    = $RuleType
        Pattern     = $Pattern
        Category    = $Category
        Application = $Application
        Reason      = $Reason
        Mandatory   = $Mandatory.IsPresent
    }
}

function Add-ProfMigExclusionRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Rule
    )

    $script:ExclusionRules += $Rule
}

function Get-ProfMigExclusionRules {
    [CmdletBinding()]
    param()

    return $script:ExclusionRules
}

function Clear-ProfMigExclusionRules {
    [CmdletBinding()]
    param()

    $script:ExclusionRules = @()
}

function Test-ProfMigExclusion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,

        [string]$Application,

        [switch]$IsDirectory
    )

    $NormalizedPath = $RelativePath -replace '/', '\'
    $NormalizedPath = $NormalizedPath.TrimStart('\')

    $FileName = Split-Path -Path $NormalizedPath -Leaf
    $Extension = [System.IO.Path]::GetExtension($FileName)

    $DirectoryParts = @()

    $ParentPath = Split-Path -Path $NormalizedPath -Parent

    if ($ParentPath) {
        $DirectoryParts = $ParentPath -split '\\'
    }

    $OrderedRules = $script:ExclusionRules | Sort-Object `
        @{ Expression = { if ($_.Mandatory) { 0 } else { 1 } } }, `
        @{ Expression = { if ($_.Category -eq 'Security') { 0 } else { 1 } } }, `
        @{ Expression = { if ($_.Application) { 0 } else { 1 } } }

    foreach ($Rule in $OrderedRules) {

        if (
            $Rule.Application -and
            $Rule.Application -ne $Application
        ) {
            continue
        }

        $IsMatch = $false

        switch ($Rule.RuleType) {

            'RelativePath' {
                if ($NormalizedPath -like $Rule.Pattern) {
                    $IsMatch = $true
                }
            }

            'FileName' {
                if ($FileName -like $Rule.Pattern) {
                    $IsMatch = $true
                }
                else {
                    foreach ($Suffix in @(
                        '-journal',
                        '-wal',
                        '-shm'
                    )) {
                        if ($FileName -like "$($Rule.Pattern)$Suffix") {
                            $IsMatch = $true
                            break
                        }
                    }
                }
            }

            'DirectoryName' {
                foreach ($Directory in $DirectoryParts) {
                    if ($Directory -like $Rule.Pattern) {
                        $IsMatch = $true
                        break
                    }
                }

                if (
                    -not $IsMatch -and
                    $IsDirectory -and
                    $FileName -like $Rule.Pattern
                ) {
                    $IsMatch = $true
                }
            }

            'Extension' {
                if ($Extension -ieq $Rule.Pattern) {
                    $IsMatch = $true
                }
            }
        }

        if ($IsMatch) {
            return [PSCustomObject]@{
                Excluded     = $true
                RuleId       = $Rule.RuleId
                RuleType     = $Rule.RuleType
                Pattern      = $Rule.Pattern
                Category     = $Rule.Category
                Application  = $Rule.Application
                Reason       = $Rule.Reason
                Mandatory    = $Rule.Mandatory
                RelativePath = $NormalizedPath
            }
        }
    }

    return [PSCustomObject]@{
        Excluded     = $false
        RuleId       = $null
        RuleType     = $null
        Pattern      = $null
        Category     = $null
        Application  = $Application
        Reason       = $null
        Mandatory    = $false
        RelativePath = $NormalizedPath
    }
}

function Initialize-ProfMigDefaultExclusions {
    [CmdletBinding()]
    param()

    Clear-ProfMigExclusionRules

    $DefaultRules = @(
        # Security
        @{
            RuleId    = 'SEC-001'
            RuleType  = 'RelativePath'
            Pattern   = 'AppData\Roaming\Microsoft\Credentials\*'
            Category  = 'Security'
            Reason    = 'Windows credential data is not portable between user profiles'
            Mandatory = $true
        },
        @{
            RuleId    = 'SEC-002'
            RuleType  = 'RelativePath'
            Pattern   = 'AppData\Local\Microsoft\Credentials\*'
            Category  = 'Security'
            Reason    = 'Windows credential data is not portable between user profiles'
            Mandatory = $true
        },
        @{
            RuleId    = 'SEC-003'
            RuleType  = 'RelativePath'
            Pattern   = 'AppData\Roaming\Microsoft\Protect\*'
            Category  = 'Security'
            Reason    = 'DPAPI-protected profile data must not be copied between profiles'
            Mandatory = $true
        },
        @{
            RuleId    = 'SEC-004'
            RuleType  = 'RelativePath'
            Pattern   = 'AppData\Local\Microsoft\Vault\*'
            Category  = 'Security'
            Reason    = 'Windows Vault data is profile-specific'
            Mandatory = $true
        },
        @{
            RuleId    = 'SEC-005'
            RuleType  = 'FileName'
            Pattern   = 'Login Data'
            Category  = 'Security'
            Reason    = 'Browser credential database is not portable'
            Mandatory = $true
        },
        @{
            RuleId    = 'SEC-006'
            RuleType  = 'Extension'
            Pattern   = '.ost'
            Category  = 'Security'
            Reason    = 'OST files should be rebuilt by Outlook'
            Mandatory = $true
        },

        # Generic
        @{
            RuleId   = 'GEN-001'
            RuleType = 'DirectoryName'
            Pattern  = 'Cache'
            Category = 'Generic'
            Reason   = 'Application cache does not need migration'
        },
        @{
            RuleId   = 'GEN-002'
            RuleType = 'DirectoryName'
            Pattern  = 'Code Cache'
            Category = 'Generic'
            Reason   = 'Application code cache does not need migration'
        },
        @{
            RuleId   = 'GEN-003'
            RuleType = 'DirectoryName'
            Pattern  = 'GPUCache'
            Category = 'Generic'
            Reason   = 'GPU cache does not need migration'
        },
        @{
            RuleId   = 'GEN-004'
            RuleType = 'DirectoryName'
            Pattern  = 'Temp'
            Category = 'Generic'
            Reason   = 'Temporary application data does not need migration'
        },
        @{
            RuleId   = 'GEN-005'
            RuleType = 'Extension'
            Pattern  = '.tmp'
            Category = 'Generic'
            Reason   = 'Temporary file'
        },

        # Chrome
        @{
            RuleId      = 'CHR-001'
            RuleType    = 'DirectoryName'
            Pattern     = 'Sessions'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Chrome session data is not portable'
        },
        @{
            RuleId      = 'CHR-002'
            RuleType    = 'DirectoryName'
            Pattern     = 'Session Storage'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Chrome session storage is not portable'
        },
        @{
            RuleId      = 'CHR-003'
            RuleType    = 'FileName'
            Pattern     = 'Login Data For Account'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Contains protected account credentials'
        },
        @{
            RuleId      = 'CHR-004'
            RuleType    = 'DirectoryName'
            Pattern     = 'Network'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'May contain cookies and authentication/session state'
        },
        @{
            RuleId      = 'CHR-005'
            RuleType    = 'FileName'
            Pattern     = 'Extension Cookies'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Contains extension cookie/session data'
        },
        @{
            RuleId      = 'CHR-006'
            RuleType    = 'FileName'
            Pattern     = 'Web Data'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'May contain autofill and payment-related information'
        },
        @{
            RuleId      = 'CHR-007'
            RuleType    = 'FileName'
            Pattern     = 'Account Web Data'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Contains Google account-specific browser data'
        },
        @{
            RuleId      = 'CHR-008'
            RuleType    = 'DirectoryName'
            Pattern     = 'Accounts'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Contains Google account state'
        },
        @{
            RuleId      = 'CHR-009'
            RuleType    = 'DirectoryName'
            Pattern     = 'Sync Data'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Contains Google synchronization state'
        },
        @{
            RuleId      = 'CHR-010'
            RuleType    = 'DirectoryName'
            Pattern     = 'GCM Store'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Contains Google messaging/account state'
        },
        @{
            RuleId      = 'CHR-011'
            RuleType    = 'DirectoryName'
            Pattern     = 'ClientCertificates'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Contains client certificate-related security data'
        },
        @{
            RuleId      = 'CHR-012'
            RuleType    = 'FileName'
            Pattern     = 'passkey_enclave_state'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Contains passkey-related security state'
        },
        @{
            RuleId      = 'CHR-013'
            RuleType    = 'FileName'
            Pattern     = 'trusted_vault.pb'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Contains trusted vault/security state'
        },
        @{
            RuleId      = 'CHR-014'
            RuleType    = 'FileName'
            Pattern     = 'EncryptedBookmarks'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Encrypted Chrome data is not migrated'
        },
        @{
            RuleId      = 'CHR-015'
            RuleType    = 'FileName'
            Pattern     = 'Secure Preferences'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Security/integrity-sensitive Chrome preferences'
        },
        @{
            RuleId      = 'CHR-016'
            RuleType    = 'DirectoryName'
            Pattern     = 'Managed Extension Settings'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Managed settings should be recreated through policy'
        },
        @{
            RuleId      = 'CHR-017'
            RuleType    = 'DirectoryName'
            Pattern     = 'Extensions'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Extension packages are inventoried but not migrated'
        },
        @{
            RuleId      = 'CHR-018'
            RuleType    = 'DirectoryName'
            Pattern     = 'Local Extension Settings'
            Category    = 'Application'
            Application = 'Chrome'
            Reason      = 'Extension state may contain sensitive or account-bound data'
        },

        # Edge
        @{
            RuleId      = 'EDG-001'
            RuleType    = 'DirectoryName'
            Pattern     = 'Sessions'
            Category    = 'Application'
            Application = 'Edge'
            Reason      = 'Edge session data is not portable'
        },
        @{
            RuleId      = 'EDG-002'
            RuleType    = 'DirectoryName'
            Pattern     = 'Session Storage'
            Category    = 'Application'
            Application = 'Edge'
            Reason      = 'Edge session storage is not portable'
        },
        @{
            RuleId      = 'EDG-003'
            RuleType    = 'DirectoryName'
            Pattern     = 'Network'
            Category    = 'Application'
            Application = 'Edge'
            Reason      = 'May contain cookies and authentication/session state'
        },
        @{
            RuleId      = 'EDG-004'
            RuleType    = 'FileName'
            Pattern     = 'Web Data'
            Category    = 'Application'
            Application = 'Edge'
            Reason      = 'May contain autofill and payment-related information'
        }
    )

    foreach ($RuleDefinition in $DefaultRules) {

        $Parameters = @{
            RuleId   = $RuleDefinition['RuleId']
            RuleType = $RuleDefinition['RuleType']
            Pattern  = $RuleDefinition['Pattern']
            Category = $RuleDefinition['Category']
            Reason   = $RuleDefinition['Reason']
        }

        if (
            $RuleDefinition.ContainsKey('Application') -and
            $RuleDefinition['Application']
        ) {
            $Parameters['Application'] = $RuleDefinition['Application']
        }

        if (
            $RuleDefinition.ContainsKey('Mandatory') -and
            $RuleDefinition['Mandatory']
        ) {
            $Parameters['Mandatory'] = $true
        }

        Add-ProfMigExclusionRule -Rule (
            New-ProfMigExclusionRule @Parameters
        )
    }
}

Export-ModuleMember -Function @(
    'New-ProfMigExclusionRule'
    'Add-ProfMigExclusionRule'
    'Get-ProfMigExclusionRules'
    'Clear-ProfMigExclusionRules'
    'Initialize-ProfMigDefaultExclusions'
    'Test-ProfMigExclusion'
)
