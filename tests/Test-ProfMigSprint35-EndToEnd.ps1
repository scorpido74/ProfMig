Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = 'C:\GitHub\ProfMig'
$permissionsPath = Join-Path $repositoryRoot 'src\Modules\ProfMig.Permissions.psm1'
$copyEnginePath = Join-Path $repositoryRoot 'src\Modules\ProfMig.CopyEngine.psm1'
$validationPath = Join-Path $repositoryRoot 'src\Modules\ProfMig.Validation.psm1'
$loggingPath = Join-Path $repositoryRoot 'src\Modules\ProfMig.Logging.psm1'

$testRoot = Join-Path $env:TEMP 'ProfMig-Sprint35-EndToEnd'
$sourceRoot = Join-Path $testRoot 'Source'
$destinationRoot = Join-Path $testRoot 'Destination'
$sourceDocuments = Join-Path $sourceRoot 'Documents'
$destinationDocuments = Join-Path $destinationRoot 'Documents'

$results = New-Object 'System.Collections.Generic.List[object]'

function Add-TestResult {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [Parameter()]
        [string]$Details = ''
    )

    $results.Add(
        [PSCustomObject]@{
            Test    = $Name
            Passed  = $Passed
            Details = $Details
        }
    )
}

function Show-TestResult {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [Parameter()]
        [string]$Details = ''
    )

    if ($Passed) {
        $status = 'PASS'
    }
    else {
        $status = 'FAIL'
    }

    Write-Host ('[{0}] {1}' -f $status, $Name)

    if (-not [string]::IsNullOrWhiteSpace($Details)) {
        Write-Host ('       {0}' -f $Details)
    }

    Add-TestResult -Name $Name -Passed $Passed -Details $Details
}

Write-Host ''
Write-Host '============================================================'
Write-Host ' ProfMig Sprint 3.5 End-to-End Verification'
Write-Host '============================================================'
Write-Host ''

# ---------------------------------------------------------------------------
# 1. Syntax validation
# ---------------------------------------------------------------------------

Write-Host '=== Syntax validation ==='

foreach ($path in @(
    $permissionsPath,
    $copyEnginePath,
    $validationPath
)) {
    $tokens = $null
    $errors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null

    $passed = ($errors.Count -eq 0)

    if ($passed) {
        $details = 'No syntax errors detected.'
    }
    else {
        $details = ($errors.Message -join '; ')
    }

    Show-TestResult `
        -Name "Syntax: $(Split-Path $path -Leaf)" `
        -Passed $passed `
        -Details $details

    if (-not $passed) {
        throw "Syntax validation failed for $path"
    }
}

# ---------------------------------------------------------------------------
# 2. Module imports
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== Module imports ==='

Remove-Module ProfMig.CopyEngine -Force -ErrorAction SilentlyContinue
Remove-Module ProfMig.Permissions -Force -ErrorAction SilentlyContinue
Remove-Module ProfMig.Validation -Force -ErrorAction SilentlyContinue
Remove-Module ProfMig.Exclusions -Force -ErrorAction SilentlyContinue
Remove-Module ProfMig.Logging -Force -ErrorAction SilentlyContinue

Import-Module $loggingPath -Force -Global -ErrorAction Stop
Import-Module $copyEnginePath -Force -ErrorAction Stop
Import-Module $permissionsPath -Force -Global -ErrorAction Stop
Import-Module $validationPath -Force -Global -ErrorAction Stop

Show-TestResult `
    -Name 'Logging import' `
    -Passed ([bool](Get-Module ProfMig.Logging))

Show-TestResult `
    -Name 'CopyEngine import' `
    -Passed ([bool](Get-Module ProfMig.CopyEngine))

Show-TestResult `
    -Name 'Permissions import' `
    -Passed ([bool](Get-Module ProfMig.Permissions))

Show-TestResult `
    -Name 'Validation import' `
    -Passed ([bool](Get-Module ProfMig.Validation))

# ---------------------------------------------------------------------------
# 3. Destination SID
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== Destination SID ==='

$profileSid = Get-ProfMigProfileSid -ProfilePath $env:USERPROFILE

if ($profileSid.Success) {
    $profileDetails = "Profile=$($profileSid.ProfilePath); SID=$($profileSid.Sid)"
}
else {
    $profileDetails = $profileSid.Error
}

Show-TestResult `
    -Name 'Destination profile SID resolved' `
    -Passed $profileSid.Success `
    -Details $profileDetails

if (-not $profileSid.Success) {
    throw 'Unable to resolve current profile SID.'
}

# ---------------------------------------------------------------------------
# 4. Build isolated test data
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== Test data ==='

Remove-Item `
    -LiteralPath $testRoot `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue

New-Item `
    -Path $sourceDocuments `
    -ItemType Directory `
    -Force |
    Out-Null

New-Item `
    -Path $destinationRoot `
    -ItemType Directory `
    -Force |
    Out-Null

'Normal migration data' |
    Set-Content -Path (Join-Path $sourceDocuments 'Normal.txt')

'Mailbox data that must be excluded' |
    Set-Content -Path (Join-Path $sourceDocuments 'Mailbox.ost')

New-Item `
    -Path (Join-Path $sourceDocuments 'SubFolder') `
    -ItemType Directory `
    -Force |
    Out-Null

'Nested migration data' |
    Set-Content -Path (Join-Path $sourceDocuments 'SubFolder\Nested.txt')

$testDataCreated = (
    (Test-Path $sourceDocuments -PathType Container) -and
    (Test-Path (Join-Path $sourceDocuments 'Normal.txt') -PathType Leaf)
)

Show-TestResult `
    -Name 'Isolated test data created' `
    -Passed $testDataCreated `
    -Details $testRoot

# ---------------------------------------------------------------------------
# 5. Component copy
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== Component copy ==='

$componentResult = Invoke-ProfMigComponentCopy `
    -Component 'Documents' `
    -SourcePath $sourceDocuments `
    -DestinationPath $destinationDocuments

$copyPassed = (
    $componentResult.FilesCopied -ge 2 -and
    $componentResult.FilesFailed -eq 0
)

$copyDetails = (
    "Copied=$($componentResult.FilesCopied); " +
    "Excluded=$($componentResult.FilesExcluded); " +
    "Failed=$($componentResult.FilesFailed); " +
    "Status=$($componentResult.Status)"
)

Show-TestResult `
    -Name 'Component copy completed' `
    -Passed $copyPassed `
    -Details $copyDetails

# ---------------------------------------------------------------------------
# 6. Exclusion validation
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== Exclusion validation ==='

$normalExists = Test-Path `
    -LiteralPath (Join-Path $destinationDocuments 'Normal.txt') `
    -PathType Leaf

$nestedExists = Test-Path `
    -LiteralPath (Join-Path $destinationDocuments 'SubFolder\Nested.txt') `
    -PathType Leaf

$ostExists = Test-Path `
    -LiteralPath (Join-Path $destinationDocuments 'Mailbox.ost') `
    -PathType Leaf

Show-TestResult `
    -Name 'Normal file copied' `
    -Passed $normalExists

Show-TestResult `
    -Name 'Nested file copied' `
    -Passed $nestedExists

if ($ostExists) {
    $ostDetails = 'Mailbox.ost was copied unexpectedly.'
}
else {
    $ostDetails = 'Mailbox.ost was not present in destination.'
}

Show-TestResult `
    -Name 'OST exclusion enforced' `
    -Passed (-not $ostExists) `
    -Details $ostDetails

# ---------------------------------------------------------------------------
# 7. Healthy ACL validation
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== Healthy ACL validation ==='

$healthyValidation = Test-ProfMigAcl `
    -Path $destinationDocuments `
    -DestinationSid $profileSid.Sid

Show-TestResult `
    -Name 'Destination user can access migrated component' `
    -Passed $healthyValidation.DestinationUserAccess `
    -Details ($healthyValidation.Findings -join ',')

Show-TestResult `
    -Name 'SYSTEM access preserved' `
    -Passed $healthyValidation.SystemAccessPresent

Show-TestResult `
    -Name 'Administrators access preserved' `
    -Passed $healthyValidation.AdministratorsPresent

# ---------------------------------------------------------------------------
# 8. Create deliberately broken ACL
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== ACL remediation scenario ==='

$repairFile = Join-Path $destinationDocuments 'RepairMe.txt'
'ACL remediation test' | Set-Content -Path $repairFile

$repairAcl = Get-Acl -LiteralPath $repairFile
$repairAcl.SetAccessRuleProtection($true, $false)

Set-Acl `
    -LiteralPath $repairFile `
    -AclObject $repairAcl

$beforeRepair = Test-ProfMigAcl `
    -Path $repairFile `
    -DestinationSid $profileSid.Sid

$brokenAclDetected = (
    -not $beforeRepair.DestinationUserAccess -and
    -not $beforeRepair.InheritanceEnabled
)

Show-TestResult `
    -Name 'Broken ACL detected' `
    -Passed $brokenAclDetected `
    -Details ($beforeRepair.Findings -join ',')

# ---------------------------------------------------------------------------
# 9. Repair through destination inheritance
# ---------------------------------------------------------------------------

$repairResult = Repair-ProfMigDestinationPermissions `
    -Path $repairFile `
    -DestinationSid $profileSid.Sid `
    -AllowInheritanceRepair

$afterRepair = Test-ProfMigAcl `
    -Path $repairFile `
    -DestinationSid $profileSid.Sid

$repairPassed = (
    $repairResult.Success -and
    $afterRepair.DestinationUserAccess
)

$repairDetails = (
    "Strategy=$($repairResult.Strategy); " +
    "Actions=$(@($repairResult.Action) -join ',')"
)

Show-TestResult `
    -Name 'ACL remediation succeeded' `
    -Passed $repairPassed `
    -Details $repairDetails

Show-TestResult `
    -Name 'Normal inheritance restored' `
    -Passed $afterRepair.InheritanceEnabled `
    -Details "InheritanceEnabled=$($afterRepair.InheritanceEnabled)"

# ---------------------------------------------------------------------------
# 10. Verify no Everyone Full Control
# ---------------------------------------------------------------------------

$finalAcl = Get-ProfMigAclInfo -Path $repairFile

$everyoneRules = @(
    $finalAcl.Access |
        Where-Object {
            $_.IdentityReference -match '(^|\\)Everyone$' -or
            $_.IdentityReference -eq 'S-1-1-0'
        }
)

if ($everyoneRules.Count -eq 0) {
    $everyoneDetails = 'No Everyone ACE present.'
}
else {
    $everyoneDetails = "Found $($everyoneRules.Count) Everyone ACE(s)."
}

Show-TestResult `
    -Name 'No Everyone permissions introduced' `
    -Passed ($everyoneRules.Count -eq 0) `
    -Details $everyoneDetails

# ---------------------------------------------------------------------------
# 11. Verify no unnecessary explicit destination ACE
# ---------------------------------------------------------------------------

$destinationExplicitRules = @()

foreach ($rule in $finalAcl.Access) {
    if ($rule.IsInherited) {
        continue
    }

    $ruleSid = $null

    if ($rule.IdentityReference -match '^S-\d-') {
        $ruleSid = $rule.IdentityReference
    }
    else {
        try {
            $account = [System.Security.Principal.NTAccount]::new(
                $rule.IdentityReference
            )

            $ruleSid = $account.Translate(
                [System.Security.Principal.SecurityIdentifier]
            ).Value
        }
        catch {
            $ruleSid = $null
        }
    }

    if ($ruleSid -eq $profileSid.Sid) {
        $destinationExplicitRules += $rule
    }
}

if ($destinationExplicitRules.Count -eq 0) {
    $explicitDetails = 'Destination access is inherited.'
}
else {
    $explicitDetails = "Found $($destinationExplicitRules.Count) explicit destination ACE(s)."
}

Show-TestResult `
    -Name 'No unnecessary explicit destination ACE' `
    -Passed ($destinationExplicitRules.Count -eq 0) `
    -Details $explicitDetails

# ---------------------------------------------------------------------------
# 12. Source SID finding behavior
# ---------------------------------------------------------------------------

$sourceSidFindingTest = Test-ProfMigAcl `
    -Path $destinationDocuments `
    -DestinationSid $profileSid.Sid `
    -SourceSid $profileSid.Sid

$sourceFindingPassed = (
    $sourceSidFindingTest.SourceSidPresent -and
    -not $sourceSidFindingTest.RemediationRequired
)

$sourceFindingDetails = (
    "SourceSidPresent=$($sourceSidFindingTest.SourceSidPresent); " +
    "RemediationRequired=$($sourceSidFindingTest.RemediationRequired); " +
    "Findings=$($sourceSidFindingTest.Findings -join ',')"
)

Show-TestResult `
    -Name 'Source SID is finding, not automatic remediation' `
    -Passed $sourceFindingPassed `
    -Details $sourceFindingDetails

# ---------------------------------------------------------------------------
# 13. Structural CopyEngine integration checks
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== CopyEngine integration ==='

$copyEngineContent = Get-Content `
    -LiteralPath $copyEnginePath `
    -Raw

$integrationChecks = @(
    @{
        Name = 'CopyEngine imports Permissions module'
        Pattern = 'ProfMig\.Permissions\.psm1'
    },
    @{
        Name = 'CopyEngine resolves destination SID'
        Pattern = 'Get-ProfMigProfileSid'
    },
    @{
        Name = 'CopyEngine performs permission repair'
        Pattern = 'Repair-ProfMigDestinationPermissions'
    },
    @{
        Name = 'CopyEngine exposes PermissionsChecked'
        Pattern = 'PermissionsChecked'
    },
    @{
        Name = 'CopyEngine exposes PermissionsRepaired'
        Pattern = 'PermissionsRepaired'
    },
    @{
        Name = 'CopyEngine exposes PermissionWarnings'
        Pattern = 'PermissionWarnings'
    },
    @{
        Name = 'CopyEngine exposes PermissionErrors'
        Pattern = 'PermissionErrors'
    },
    @{
        Name = 'CopyEngine exposes PermissionResults'
        Pattern = 'PermissionResults'
    }
)

foreach ($check in $integrationChecks) {
    $integrationPassed = ($copyEngineContent -match $check.Pattern)

    Show-TestResult `
        -Name $check.Name `
        -Passed $integrationPassed
}

# ---------------------------------------------------------------------------
# 14. Summary
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '============================================================'
Write-Host ' Sprint 3.5 Summary'
Write-Host '============================================================'
Write-Host ''

$summary = @(
    $results |
        Select-Object `
            @{Name='Result'; Expression={
                if ($_.Passed) { 'PASS' } else { 'FAIL' }
            }},
            Test,
            Details
)

$summary | Format-Table -AutoSize

$failed = @(
    $results |
        Where-Object { -not $_.Passed }
)

Write-Host ''

if ($failed.Count -eq 0) {
    Write-Host 'SPRINT 3.5 END-TO-END RESULT: PASS'
    Write-Host 'All tested acceptance criteria passed.'
    exit 0
}

Write-Host "SPRINT 3.5 END-TO-END RESULT: FAIL ($($failed.Count) failed test(s))"
exit 1
