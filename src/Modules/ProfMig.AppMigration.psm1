<#
.SYNOPSIS
    Generic application migration framework for ProfMig.

.DESCRIPTION
    Provides reusable functionality for loading, validating and processing
    application migration definitions.

    Application-specific migration rules are stored separately from the
    migration engine so that new applications can be supported without
    implementing new copy logic.

.NOTES
    Project : ProfMig
    Module  : ProfMig.AppMigration
    Sprint  : 2.5 - Generic AppData Migration Framework
#>

Set-StrictMode -Version Latest


# ---------------------------------------------------------------------------
# Public function: Test-ProfMigApplicationDefinition
# ---------------------------------------------------------------------------

function Test-ProfMigApplicationDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Definition
    )

    $errors = @()

    # -----------------------------------------------------------------------
    # Schema version
    # -----------------------------------------------------------------------

    if (
        -not $Definition.ContainsKey('SchemaVersion') -or
        [string]::IsNullOrWhiteSpace(
            [string]$Definition.SchemaVersion
        )
    ) {
        $errors += 'SchemaVersion is required.'
    }


    # -----------------------------------------------------------------------
    # Application metadata
    # -----------------------------------------------------------------------

    if (
        -not $Definition.ContainsKey('Application') -or
        $null -eq $Definition.Application
    ) {
        $errors += 'Application section is required.'
    }
    else {

        if (
            -not $Definition.Application.ContainsKey('Id') -or
            [string]::IsNullOrWhiteSpace(
                [string]$Definition.Application.Id
            )
        ) {
            $errors += 'Application.Id is required.'
        }

        if (
            -not $Definition.Application.ContainsKey('Name') -or
            [string]::IsNullOrWhiteSpace(
                [string]$Definition.Application.Name
            )
        ) {
            $errors += 'Application.Name is required.'
        }
    }


    # -----------------------------------------------------------------------
    # Detection rules
    # -----------------------------------------------------------------------

    if (
        -not $Definition.ContainsKey('Detection') -or
        @($Definition.Detection).Count -eq 0
    ) {
        $errors += 'At least one detection rule is required.'
    }


    # -----------------------------------------------------------------------
    # Migration definitions
    # -----------------------------------------------------------------------

    if (
        -not $Definition.ContainsKey('Migration') -or
        @($Definition.Migration).Count -eq 0
    ) {
        $errors += 'At least one migration definition is required.'
    }
    else {

        foreach ($migration in @($Definition.Migration)) {

            if (
                -not $migration.ContainsKey('Name') -or
                [string]::IsNullOrWhiteSpace(
                    [string]$migration.Name
                )
            ) {
                $errors += 'Migration.Name is required.'
            }


            # ---------------------------------------------------------------
            # Source and destination
            # ---------------------------------------------------------------

            foreach ($sectionName in @('Source', 'Destination')) {

                if (
                    -not $migration.ContainsKey($sectionName) -or
                    $null -eq $migration[$sectionName]
                ) {
                    $errors += (
                        "Migration '$($migration.Name)' requires a $sectionName section."
                    )

                    continue
                }

                $section = $migration[$sectionName]

                if (
                    -not $section.ContainsKey('Root') -or
                    [string]::IsNullOrWhiteSpace(
                        [string]$section.Root
                    )
                ) {
                    $errors += (
                        "Migration '$($migration.Name)' $sectionName.Root is required."
                    )
                }
                elseif (
                    $section.Root -notin @(
                        'APPDATA',
                        'LOCALAPPDATA'
                    )
                ) {
                    $errors += (
                        "Migration '$($migration.Name)' contains unsupported " +
                        "$sectionName.Root '$($section.Root)'."
                    )
                }

                if (
                    -not $section.ContainsKey('Path') -or
                    [string]::IsNullOrWhiteSpace(
                        [string]$section.Path
                    )
                ) {
                    $errors += (
                        "Migration '$($migration.Name)' $sectionName.Path is required."
                    )
                }
                else {

                    $path = [string]$section.Path

                    if ([System.IO.Path]::IsPathRooted($path)) {
                        $errors += (
                            "Migration '$($migration.Name)' $sectionName.Path " +
                            'must be relative.'
                        )
                    }

                    $normalizedPath = $path.Replace('/', '\')

                    $segments = @(
                        $normalizedPath.Split('\') |
                            Where-Object {
                                -not [string]::IsNullOrWhiteSpace($_)
                            }
                    )

                    if (
                        $segments -contains '.' -or
                        $segments -contains '..'
                    ) {
                        $errors += (
                            "Migration '$($migration.Name)' $sectionName.Path " +
                            'contains an invalid path segment.'
                        )
                    }
                }
            }
        }
    }


    # -----------------------------------------------------------------------
    # Return structured validation result
    # -----------------------------------------------------------------------

    return [PSCustomObject]@{
        Valid  = ($errors.Count -eq 0)
        Errors = @($errors)
    }
}


# ---------------------------------------------------------------------------
# Public function: Get-ProfMigApplicationDefinitions
# ---------------------------------------------------------------------------

function Get-ProfMigApplicationDefinitions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Application definition folder not found: $Path"
    }

    $definitionFiles = @(
        Get-ChildItem `
            -LiteralPath $Path `
            -Filter '*.psd1' `
            -File `
            -ErrorAction Stop
    )

    $definitions = @()

    foreach ($file in $definitionFiles) {

        try {

            $definition = Import-PowerShellDataFile `
                -LiteralPath $file.FullName `
                -ErrorAction Stop

            $validation = Test-ProfMigApplicationDefinition `
                -Definition $definition

            $definitions += [PSCustomObject]@{
                File       = $file.FullName
                Definition = $definition
                Valid      = $validation.Valid
                Errors     = @($validation.Errors)
            }
        }
        catch {

            $definitions += [PSCustomObject]@{
                File       = $file.FullName
                Definition = $null
                Valid      = $false
                Errors     = @($_.Exception.Message)
            }
        }
    }

    return @($definitions)
}


# ---------------------------------------------------------------------------
# Public function: Get-ProfMigApplicationDefinition
# ---------------------------------------------------------------------------

function Get-ProfMigApplicationDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Id
    )

    $definitions = @(
        Get-ProfMigApplicationDefinitions -Path $Path
    )

    $matches = @(
        $definitions |
            Where-Object {
                $_.Valid -and
                $null -ne $_.Definition -and
                $_.Definition.Application.Id -ieq $Id
            }
    )

    if ($matches.Count -eq 0) {
        return $null
    }

    if ($matches.Count -gt 1) {
        throw "Multiple application definitions found with Id '$Id'."
    }

    return $matches[0]
}

# ---------------------------------------------------------------------------
# Public function: Resolve-ProfMigApplicationPath
# ---------------------------------------------------------------------------

function Resolve-ProfMigApplicationPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath,

        [Parameter(Mandatory)]
        [ValidateSet(
            'APPDATA',
            'LOCALAPPDATA'
        )]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )


    # -----------------------------------------------------------------------
    # Validate profile path
    # -----------------------------------------------------------------------

    if (
        -not (
            Test-Path `
                -LiteralPath $ProfilePath `
                -PathType Container
        )
    ) {
        throw "Profile path does not exist: $ProfilePath"
    }


    # -----------------------------------------------------------------------
    # Resolve profile path
    # -----------------------------------------------------------------------

    $resolvedProfile = (
        Resolve-Path `
            -LiteralPath $ProfilePath `
            -ErrorAction Stop
    ).Path.TrimEnd('\')


    # -----------------------------------------------------------------------
    # Validate relative application path
    # -----------------------------------------------------------------------

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Application relative path cannot be empty.'
    }

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Application path must be relative: $RelativePath"
    }

    $normalizedRelativePath = $RelativePath.Replace('/', '\').Trim('\')

    if ([string]::IsNullOrWhiteSpace($normalizedRelativePath)) {
        throw 'Application relative path cannot be empty.'
    }

    $segments = @(
        $normalizedRelativePath.Split('\')
    )

    foreach ($segment in $segments) {

        if (
            [string]::IsNullOrWhiteSpace($segment) -or
            $segment -eq '.' -or
            $segment -eq '..'
        ) {
            throw "Invalid application relative path: $RelativePath"
        }
    }


    # -----------------------------------------------------------------------
    # Resolve supported application root
    # -----------------------------------------------------------------------

    switch ($Root) {

        'APPDATA' {

            $rootPath = Join-Path `
                -Path $resolvedProfile `
                -ChildPath 'AppData\Roaming'
        }

        'LOCALAPPDATA' {

            $rootPath = Join-Path `
                -Path $resolvedProfile `
                -ChildPath 'AppData\Local'
        }

        default {

            throw "Unsupported application root: $Root"
        }
    }


    # -----------------------------------------------------------------------
    # Build application path
    # -----------------------------------------------------------------------

    $applicationPath = Join-Path `
        -Path $rootPath `
        -ChildPath $normalizedRelativePath


    # -----------------------------------------------------------------------
    # Security boundary check
    #
    # The resulting path must remain below the selected AppData root.
    # -----------------------------------------------------------------------

    $fullRootPath = [System.IO.Path]::GetFullPath(
        $rootPath
    ).TrimEnd('\')

    $fullApplicationPath = [System.IO.Path]::GetFullPath(
        $applicationPath
    ).TrimEnd('\')

    $requiredPrefix = $fullRootPath + '\'

    if (
        -not $fullApplicationPath.StartsWith(
            $requiredPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw (
            "Resolved application path escapes the allowed $Root root: " +
            $RelativePath
        )
    }


    return $fullApplicationPath
}

# ---------------------------------------------------------------------------
# Public function: Test-ProfMigApplicationDetection
# ---------------------------------------------------------------------------

function Test-ProfMigApplicationDetection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Definition,

        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $validation = Test-ProfMigApplicationDefinition `
        -Definition $Definition

    if (-not $validation.Valid) {

        throw (
            'Application definition is invalid: ' +
            ($validation.Errors -join '; ')
        )
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $ProfilePath `
                -PathType Container
        )
    ) {
        throw "Profile path does not exist: $ProfilePath"
    }


    # -----------------------------------------------------------------------
    # Process detection rules
    # -----------------------------------------------------------------------

    $ruleResults = @()

    foreach ($rule in @($Definition.Detection)) {

        $ruleType = [string]$rule.Type

        switch ($ruleType) {

            'PathExists' {

                if (
                    -not $rule.ContainsKey('Root') -or
                    -not $rule.ContainsKey('Path')
                ) {
                    throw (
                        'PathExists detection rule requires Root and Path.'
                    )
                }

                $resolvedPath = Resolve-ProfMigApplicationPath `
                    -ProfilePath $ProfilePath `
                    -Root $rule.Root `
                    -RelativePath $rule.Path

                $exists = Test-Path `
                    -LiteralPath $resolvedPath

                $ruleResults += [PSCustomObject]@{
                    Type         = $ruleType
                    Root         = $rule.Root
                    RelativePath = $rule.Path
                    ResolvedPath = $resolvedPath
                    Matched      = $exists
                    Error        = $null
                }
            }

            default {

                $ruleResults += [PSCustomObject]@{
                    Type         = $ruleType
                    Root         = $null
                    RelativePath = $null
                    ResolvedPath = $null
                    Matched      = $false
                    Error        = (
                        "Unsupported detection rule type: $ruleType"
                    )
                }
            }
        }
    }


    # -----------------------------------------------------------------------
    # Detection policy
    #
    # At least one configured detection rule must match.
    # -----------------------------------------------------------------------

    $matchedRules = @(
        $ruleResults |
            Where-Object {
                $_.Matched
            }
    )

    $detected = ($matchedRules.Count -gt 0)

    $status = if ($detected) {
        'Detected'
    }
    else {
        'NotDetected'
    }


    # -----------------------------------------------------------------------
    # Return structured detection result
    # -----------------------------------------------------------------------

    return [PSCustomObject]@{
        ApplicationId   = $Definition.Application.Id
        ApplicationName = $Definition.Application.Name
        ProfilePath     = $ProfilePath

        Detected        = $detected
        Status          = $status

        RulesEvaluated  = $ruleResults.Count
        RulesMatched    = $matchedRules.Count

        Rules           = @($ruleResults)
    }
}

# ---------------------------------------------------------------------------
# Public function: Get-ProfMigApplicationMigrationPlan
# ---------------------------------------------------------------------------

function Get-ProfMigApplicationMigrationPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Definition,

        [Parameter(Mandatory)]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [string]$DestinationProfile
    )

    $validation = Test-ProfMigApplicationDefinition `
        -Definition $Definition

    if (-not $validation.Valid) {
        throw (
            'Application definition is invalid: ' +
            ($validation.Errors -join '; ')
        )
    }

    if (-not (Test-Path -LiteralPath $SourceProfile -PathType Container)) {
        throw "Source profile does not exist: $SourceProfile"
    }

    if (-not (Test-Path -LiteralPath $DestinationProfile -PathType Container)) {
        throw "Destination profile does not exist: $DestinationProfile"
    }

    $resolvedSourceProfile = (
        Resolve-Path -LiteralPath $SourceProfile -ErrorAction Stop
    ).Path.TrimEnd('\')

    $resolvedDestinationProfile = (
        Resolve-Path -LiteralPath $DestinationProfile -ErrorAction Stop
    ).Path.TrimEnd('\')

    if ($resolvedSourceProfile -ieq $resolvedDestinationProfile) {
        throw 'Source and destination profiles cannot be the same.'
    }


    # -----------------------------------------------------------------------
    # Detect application
    # -----------------------------------------------------------------------

    $detection = Test-ProfMigApplicationDetection `
        -Definition $Definition `
        -ProfilePath $resolvedSourceProfile

    if (-not $detection.Detected) {

        return [PSCustomObject]@{
            ApplicationId     = $Definition.Application.Id
            ApplicationName   = $Definition.Application.Name
            SourceProfile     = $resolvedSourceProfile
            DestinationProfile = $resolvedDestinationProfile

            Detected          = $false
            Status            = 'NotDetected'

            FilesDetected     = 0
            FilesIncluded     = 0
            FilesExcluded     = 0
            FilesNotIncluded  = 0
            BytesSelected     = [int64]0

            Locations         = @()
            Items             = @()
        }
    }


    # -----------------------------------------------------------------------
    # Process migration locations
    # -----------------------------------------------------------------------

    $locations = @()
    $allItems = @()

    $totalDetected    = 0
    $totalIncluded    = 0
    $totalExcluded    = 0
    $totalNotIncluded = 0
    $totalBytesSelected = [int64]0

    foreach ($migration in @($Definition.Migration)) {

        $sourcePath = Resolve-ProfMigApplicationPath `
            -ProfilePath $resolvedSourceProfile `
            -Root $migration.Source.Root `
            -RelativePath $migration.Source.Path

        $destinationPath = Resolve-ProfMigApplicationPath `
            -ProfilePath $resolvedDestinationProfile `
            -Root $migration.Destination.Root `
            -RelativePath $migration.Destination.Path

        $includeRules = @($migration.Include)
        $excludeRules = @($migration.Exclude)

        $locationItems = @()


        if (Test-Path -LiteralPath $sourcePath -PathType Container) {

            $files = @(
                Get-ChildItem `
                    -LiteralPath $sourcePath `
                    -File `
                    -Recurse `
                    -Force `
                    -ErrorAction Stop
            )

            foreach ($file in $files) {

                $relativePath = $file.FullName.Substring(
                    $sourcePath.Length
                ).TrimStart('\')

                $included = $false
                $includeRule = $null

                foreach ($rule in $includeRules) {

                    if (
                        $relativePath -like $rule -or
                        $file.Name -like $rule
                    ) {
                        $included = $true
                        $includeRule = $rule
                        break
                    }
                }


                # -----------------------------------------------------------
                # Exclusions always override includes
                # -----------------------------------------------------------

                $excluded = $false
                $excludeRule = $null

                foreach ($rule in $excludeRules) {

                    $normalizedRule = $rule.Replace('/', '\')
                    $normalizedRelative = $relativePath.Replace('/', '\')

                    if (
                        $normalizedRelative -like $normalizedRule -or
                        $file.Name -like $normalizedRule -or
                        $normalizedRelative -like "$($normalizedRule.TrimEnd('\'))\*"
                    ) {
                        $excluded = $true
                        $excludeRule = $rule
                        break
                    }
                }


                if (-not $included) {
                    $selectionStatus = 'NotIncluded'
                    $reason = 'No include rule matched'
                }
                elseif ($excluded) {
                    $selectionStatus = 'Excluded'
                    $reason = "Excluded by rule: $excludeRule"
                }
                else {
                    $selectionStatus = 'Included'
                    $reason = "Included by rule: $includeRule"
                }


                $destinationFile = Join-Path `
                    -Path $destinationPath `
                    -ChildPath $relativePath

                $item = [PSCustomObject]@{
                    Location        = $migration.Name
                    RelativePath    = $relativePath
                    SourceFile      = $file.FullName
                    DestinationFile = $destinationFile
                    Length          = [int64]$file.Length
                    Status          = $selectionStatus
                    IncludeRule     = $includeRule
                    ExcludeRule     = $excludeRule
                    Reason          = $reason
                }

                $locationItems += $item
                $allItems += $item

                $totalDetected++

            switch ($selectionStatus) {

                'Included' {
                    $totalIncluded++
                    $totalBytesSelected += $file.Length
                }

                'Excluded' {
                    $totalExcluded++
                }

                'NotIncluded' {
                    $totalNotIncluded++
                }
             }
          }
        }


        $locations += [PSCustomObject]@{
            Name            = $migration.Name
            SourcePath      = $sourcePath
            DestinationPath = $destinationPath
            Items           = @($locationItems)
        }
    }


    # -----------------------------------------------------------------------
    # Determine plan status
    # -----------------------------------------------------------------------

    $status = if ($totalIncluded -gt 0) {
        'Ready'
    }
    else {
        'NothingToMigrate'
    }


    return [PSCustomObject]@{
        ApplicationId      = $Definition.Application.Id
        ApplicationName    = $Definition.Application.Name

        SourceProfile      = $resolvedSourceProfile
        DestinationProfile = $resolvedDestinationProfile

        Detected           = $true
        Status             = $status

        FilesDetected      = $totalDetected
        FilesIncluded      = $totalIncluded
        FilesExcluded      = $totalExcluded
        FilesNotIncluded   = $totalNotIncluded
        BytesSelected      = $totalBytesSelected

        Locations          = @($locations)
        Items              = @($allItems)
    }
}

# ---------------------------------------------------------------------------
# Public function: Invoke-ProfMigApplicationMigration
# ---------------------------------------------------------------------------

function Invoke-ProfMigApplicationMigration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Definition,

        [Parameter(Mandatory)]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [string]$DestinationProfile
    )

    $startedAt = Get-Date


    # -----------------------------------------------------------------------
    # Ensure CopyEngine integration is available
    # -----------------------------------------------------------------------

    if (
        -not (
            Get-Command `
                -Name 'Invoke-ProfMigFileCopy' `
                -ErrorAction SilentlyContinue
        )
    ) {
        throw (
            'ProfMig CopyEngine is not loaded or ' +
            'Invoke-ProfMigFileCopy is unavailable.'
        )
    }

    # -----------------------------------------------------------------------
    # Pre-migration validation
    # -----------------------------------------------------------------------

    $preValidation = Test-ProfMigApplicationValidation `
        -Definition $Definition `
        -ProfilePath $SourceProfile `
        -Phase PreMigration

    if (-not $preValidation.Valid) {

    $completedAt = Get-Date

    return [PSCustomObject]@{
        ApplicationId      = $Definition.Application.Id
        ApplicationName    = $Definition.Application.Name

        SourceProfile      = $SourceProfile
        DestinationProfile = $DestinationProfile

        StartedAt          = $startedAt
        CompletedAt        = $completedAt
        Duration           = ($completedAt - $startedAt)

        Status             = 'Blocked'

        Plan               = $null

        PreValidation      = $preValidation
        PostValidation     = $null

        FilesSelected      = 0
        FilesCopied        = 0
        FilesSkipped       = 0
        FilesExcluded      = 0
        FilesFailed        = 0
        BytesCopied        = [int64]0

        Components         = @()
        SkippedItems       = @()
        ExcludedItems      = @()
        Errors             = @($preValidation.Errors)
    }
}

    # -----------------------------------------------------------------------
    # Build migration plan
    # -----------------------------------------------------------------------

    $plan = Get-ProfMigApplicationMigrationPlan `
        -Definition $Definition `
        -SourceProfile $SourceProfile `
        -DestinationProfile $DestinationProfile


    # -----------------------------------------------------------------------
    # Handle non-runnable plans
    # -----------------------------------------------------------------------

    if ($plan.Status -eq 'NotDetected') {

        $completedAt = Get-Date

        return [PSCustomObject]@{
            ApplicationId      = $plan.ApplicationId
            ApplicationName    = $plan.ApplicationName

            SourceProfile      = $plan.SourceProfile
            DestinationProfile = $plan.DestinationProfile

            StartedAt          = $startedAt
            CompletedAt        = $completedAt
            Duration           = ($completedAt - $startedAt)

            Status             = 'NotDetected'

            Plan               = $plan

            FilesSelected      = 0
            FilesCopied        = 0
            FilesSkipped       = 0
            FilesExcluded      = 0
            FilesFailed        = 0
            BytesCopied        = [int64]0

            Components         = @()
            SkippedItems       = @()
            ExcludedItems      = @()
            Errors             = @()
        }
    }

    if ($plan.Status -eq 'NothingToMigrate') {

        $completedAt = Get-Date

        return [PSCustomObject]@{
            ApplicationId      = $plan.ApplicationId
            ApplicationName    = $plan.ApplicationName

            SourceProfile      = $plan.SourceProfile
            DestinationProfile = $plan.DestinationProfile

            StartedAt          = $startedAt
            CompletedAt        = $completedAt
            Duration           = ($completedAt - $startedAt)

            Status             = 'NothingToMigrate'

            Plan               = $plan

            FilesSelected      = 0
            FilesCopied        = 0
            FilesSkipped       = 0
            FilesExcluded      = $plan.FilesExcluded
            FilesFailed        = 0
            BytesCopied        = [int64]0

            Components         = @()
            SkippedItems       = @()
            ExcludedItems      = @(
                $plan.Items |
                    Where-Object {
                        $_.Status -eq 'Excluded'
                    }
            )
            Errors             = @()
        }
    }


    # -----------------------------------------------------------------------
    # Execute selected files
    # -----------------------------------------------------------------------

    $components    = @()
    $skippedItems  = @()
    $excludedItems = @(
        $plan.Items |
            Where-Object {
                $_.Status -eq 'Excluded'
            }
    )
    $errors = @()

    foreach (
        $item in @(
            $plan.Items |
                Where-Object {
                    $_.Status -eq 'Included'
                }
        )
    ) {

        $componentName = (
            '{0}:{1}' -f
                $plan.ApplicationId,
                $item.Location
        )

        $copyResult = Invoke-ProfMigFileCopy `
            -Component $componentName `
            -SourceFile $item.SourceFile `
            -DestinationFile $item.DestinationFile

        $components += $copyResult

        if ($copyResult.SkippedItems.Count -gt 0) {
            $skippedItems += $copyResult.SkippedItems
        }

        if ($copyResult.Errors.Count -gt 0) {
            $errors += $copyResult.Errors
        }
    }


    # -----------------------------------------------------------------------
    # Calculate totals
    # -----------------------------------------------------------------------

    $filesSelected = 0
    $filesCopied   = 0
    $filesSkipped  = 0
    $filesFailed   = 0
    $bytesCopied   = [int64]0

    foreach ($component in $components) {

        $filesSelected += $component.FilesSelected
        $filesCopied   += $component.FilesCopied
        $filesSkipped  += $component.FilesSkipped
        $filesFailed   += $component.FilesFailed
        $bytesCopied   += $component.BytesCopied
    }

    # -----------------------------------------------------------------------
    # Post-migration validation
    # -----------------------------------------------------------------------

    $postValidation = Test-ProfMigApplicationValidation `
        -Definition $Definition `
        -ProfilePath $plan.DestinationProfile `
        -Phase PostMigration

    if (-not $postValidation.Valid) {

        foreach ($validationError in $postValidation.Errors) {

            $errors += [PSCustomObject]@{
                Component       = $plan.ApplicationId
                SourceFile      = $null
                DestinationFile = $plan.DestinationProfile
                Error           = $validationError
            }
        }
    }


    # -----------------------------------------------------------------------
    # Determine migration status
    # -----------------------------------------------------------------------

    if (
        $filesFailed -gt 0 -or
        $errors.Count -gt 0 -or
        -not $postValidation.Valid
    ) {
        $status = 'CompletedWithErrors'
    }
    elseif ($filesSkipped -gt 0) {
        $status = 'CompletedWithWarnings'
    }
    else {
        $status = 'Success'
    }

    $completedAt = Get-Date


    return [PSCustomObject]@{
        ApplicationId      = $plan.ApplicationId
        ApplicationName    = $plan.ApplicationName

        SourceProfile      = $plan.SourceProfile
        DestinationProfile = $plan.DestinationProfile

        StartedAt          = $startedAt
        CompletedAt        = $completedAt
        Duration           = ($completedAt - $startedAt)

        Status             = $status

        Plan               = $plan

        PreValidation      = $preValidation
        PostValidation     = $postValidation

        FilesSelected      = $filesSelected
        FilesCopied        = $filesCopied
        FilesSkipped       = $filesSkipped
        FilesExcluded      = $plan.FilesExcluded
        FilesFailed        = $filesFailed
        BytesCopied        = $bytesCopied

        Components         = @($components)
        SkippedItems       = @($skippedItems)
        ExcludedItems      = @($excludedItems)
        Errors             = @($errors)
    }
}

# ---------------------------------------------------------------------------
# Public function: Test-ProfMigApplicationValidation
# ---------------------------------------------------------------------------

function Test-ProfMigApplicationValidation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Definition,

        [Parameter(Mandatory)]
        [string]$ProfilePath,

        [Parameter()]
        [ValidateSet(
            'PreMigration',
            'PostMigration'
        )]
        [string]$Phase = 'PostMigration'
    )

    $definitionValidation = Test-ProfMigApplicationDefinition `
        -Definition $Definition

    if (-not $definitionValidation.Valid) {
        throw (
            'Application definition is invalid: ' +
            ($definitionValidation.Errors -join '; ')
        )
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $ProfilePath `
                -PathType Container
        )
    ) {
        throw "Profile path does not exist: $ProfilePath"
    }


    # -----------------------------------------------------------------------
    # No validation rules
    # -----------------------------------------------------------------------

    if (
        -not $Definition.ContainsKey('Validation') -or
        @($Definition.Validation).Count -eq 0
    ) {

        return [PSCustomObject]@{
            ApplicationId  = $Definition.Application.Id
            ProfilePath    = $ProfilePath
            Phase          = $Phase

            Valid          = $true
            Status         = 'NoValidationRules'

            RulesEvaluated = 0
            RulesPassed    = 0
            RulesFailed    = 0

            Rules          = @()
            Errors         = @()
        }
    }


    # -----------------------------------------------------------------------
    # Process validation rules
    # -----------------------------------------------------------------------

    $ruleResults = @()
    $errors      = @()

    foreach ($rule in @($Definition.Validation)) {

        $ruleType = [string]$rule.Type

        switch ($ruleType) {

            'PathExists' {

                if (
                    -not $rule.ContainsKey('Root') -or
                    -not $rule.ContainsKey('Path')
                ) {

                    $message = (
                        'PathExists validation rule requires Root and Path.'
                    )

                    $errors += $message

                    $ruleResults += [PSCustomObject]@{
                        Type         = $ruleType
                        Root         = $null
                        RelativePath = $null
                        ResolvedPath = $null
                        Passed       = $false
                        Error        = $message
                    }

                    continue
                }

                try {

                    $resolvedPath = Resolve-ProfMigApplicationPath `
                        -ProfilePath $ProfilePath `
                        -Root $rule.Root `
                        -RelativePath $rule.Path

                    $passed = Test-Path `
                        -LiteralPath $resolvedPath

                    $errorMessage = $null

                    if (-not $passed) {
                        $errorMessage = (
                            "Required path does not exist: $resolvedPath"
                        )
                    }

                    $ruleResults += [PSCustomObject]@{
                        Type         = $ruleType
                        Root         = $rule.Root
                        RelativePath = $rule.Path
                        ResolvedPath = $resolvedPath
                        Passed       = $passed
                        Error        = $errorMessage
                    }

                    if ($null -ne $errorMessage) {
                        $errors += $errorMessage
                    }
                }
                catch {

                    $errors += $_.Exception.Message

                    $ruleResults += [PSCustomObject]@{
                        Type         = $ruleType
                        Root         = $rule.Root
                        RelativePath = $rule.Path
                        ResolvedPath = $null
                        Passed       = $false
                        Error        = $_.Exception.Message
                    }
                }
            }


            default {

                $message = (
                    "Unsupported validation rule type: $ruleType"
                )

                $errors += $message

                $ruleResults += [PSCustomObject]@{
                    Type         = $ruleType
                    Root         = $null
                    RelativePath = $null
                    ResolvedPath = $null
                    Passed       = $false
                    Error        = $message
                }
            }
        }
    }


    # -----------------------------------------------------------------------
    # Calculate validation result
    # -----------------------------------------------------------------------

    $passedRules = @(
        $ruleResults |
            Where-Object {
                $_.Passed
            }
    )

    $failedRules = @(
        $ruleResults |
            Where-Object {
                -not $_.Passed
            }
    )

    $valid = ($failedRules.Count -eq 0)

    $status = if ($valid) {
        'Success'
    }
    else {
        'Failed'
    }


    return [PSCustomObject]@{
        ApplicationId  = $Definition.Application.Id
        ProfilePath    = $ProfilePath
        Phase          = $Phase

        Valid          = $valid
        Status         = $status

        RulesEvaluated = $ruleResults.Count
        RulesPassed    = $passedRules.Count
        RulesFailed    = $failedRules.Count

        Rules          = @($ruleResults)
        Errors         = @($errors)
    }
}

# ---------------------------------------------------------------------------
# Public function: ConvertTo-ProfMigApplicationCopyResult
# ---------------------------------------------------------------------------

function ConvertTo-ProfMigApplicationCopyResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$ApplicationResult
    )

    $requiredProperties = @(
        'ApplicationId'
        'SourceProfile'
        'DestinationProfile'
        'StartedAt'
        'CompletedAt'
        'Duration'
        'Status'
        'FilesSelected'
        'FilesCopied'
        'FilesSkipped'
        'FilesExcluded'
        'FilesFailed'
        'BytesCopied'
        'Components'
        'SkippedItems'
        'ExcludedItems'
        'Errors'
    )

    foreach ($property in $requiredProperties) {
        if ($null -eq $ApplicationResult.PSObject.Properties[$property]) {
            throw (
                "Application migration result is missing " +
                "required property '$property'."
            )
        }
    }

    switch ($ApplicationResult.Status) {
        'Success'               { $copyStatus = 'Success' }
        'CompletedWithWarnings' { $copyStatus = 'CompletedWithWarnings' }
        'CompletedWithErrors'   { $copyStatus = 'CompletedWithErrors' }
        'Blocked'               { $copyStatus = 'CompletedWithErrors' }
        'NotDetected'           { $copyStatus = 'CompletedWithWarnings' }
        'NothingToMigrate'      { $copyStatus = 'CompletedWithWarnings' }
        default                 { $copyStatus = 'CompletedWithErrors' }
    }

    # Normalize excluded application-plan items to the reporting contract.
    $normalizedExcludedItems = @(
        foreach ($excludedItem in @($ApplicationResult.ExcludedItems)) {
            $location = $null

            if ($null -ne $excludedItem.PSObject.Properties['Location']) {
                $location = [string]$excludedItem.Location
            }

            $componentName = $ApplicationResult.ApplicationId

            if (-not [string]::IsNullOrWhiteSpace($location)) {
                $componentName = '{0}:{1}' -f `
                    $ApplicationResult.ApplicationId,
                    $location
            }

            [PSCustomObject]@{
                Component       = $componentName
                SourceFile      = $excludedItem.SourceFile
                DestinationFile = $excludedItem.DestinationFile
                Reason          = $excludedItem.Reason
                Location        = $location
                RelativePath    = $excludedItem.RelativePath
                IncludeRule     = $excludedItem.IncludeRule
                ExcludeRule     = $excludedItem.ExcludeRule
            }
        }
    )

    # Normalize errors. CopyEngine errors are already structured, while
    # blocked pre-validation can return plain strings.
    $normalizedErrors = @(
        foreach ($errorItem in @($ApplicationResult.Errors)) {
            if ($errorItem -is [string]) {
                [PSCustomObject]@{
                    Component       = $ApplicationResult.ApplicationId
                    SourceFile      = $ApplicationResult.SourceProfile
                    DestinationFile = $ApplicationResult.DestinationProfile
                    Error           = $errorItem
                }

                continue
            }

            $component = $ApplicationResult.ApplicationId
            $sourceFile = $null
            $destinationFile = $ApplicationResult.DestinationProfile
            $message = $null

            if ($null -ne $errorItem.PSObject.Properties['Component']) {
                $component = $errorItem.Component
            }

            if ($null -ne $errorItem.PSObject.Properties['SourceFile']) {
                $sourceFile = $errorItem.SourceFile
            }

            if ($null -ne $errorItem.PSObject.Properties['DestinationFile']) {
                $destinationFile = $errorItem.DestinationFile
            }

            if ($null -ne $errorItem.PSObject.Properties['Error']) {
                $message = $errorItem.Error
            }
            elseif ($null -ne $errorItem.PSObject.Properties['Reason']) {
                $message = $errorItem.Reason
            }
            else {
                $message = [string]$errorItem
            }

            [PSCustomObject]@{
                Component       = $component
                SourceFile      = $sourceFile
                DestinationFile = $destinationFile
                Error           = $message
            }
        }
    )

    $components = @()
    $sourceComponents = @($ApplicationResult.Components)

    if ($sourceComponents.Count -gt 0) {
        $componentGroups = @(
            $sourceComponents |
                Group-Object -Property Component
        )

        foreach ($group in $componentGroups) {
            $groupItems = @($group.Group)

            $componentPrefix = $ApplicationResult.ApplicationId + ':'

            if (
                $group.Name.StartsWith(
                    $componentPrefix,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            ) {
                $locationName = $group.Name.Substring(
                    $componentPrefix.Length
                )
            }
            else {
                $locationName = $group.Name
            }

            $filesSelected = (
                $groupItems |
                    Measure-Object -Property FilesSelected -Sum
            ).Sum

            $filesCopied = (
                $groupItems |
                    Measure-Object -Property FilesCopied -Sum
            ).Sum

            $filesSkipped = (
                $groupItems |
                    Measure-Object -Property FilesSkipped -Sum
            ).Sum

            $filesFailed = (
                $groupItems |
                    Measure-Object -Property FilesFailed -Sum
            ).Sum

            $bytesCopied = (
                $groupItems |
                    Measure-Object -Property BytesCopied -Sum
            ).Sum

            $groupSkippedItems = @(
                foreach ($item in $groupItems) {
                    foreach ($skippedItem in @($item.SkippedItems)) {
                        $skippedItem
                    }
                }
            )

            $groupExcludedItems = @(
                $normalizedExcludedItems |
                    Where-Object {
                        $_.Location -eq $locationName
                    }
            )

            $groupErrors = @(
                foreach ($item in $groupItems) {
                    foreach ($errorItem in @($item.Errors)) {
                        $errorItem
                    }
                }
            )

            $filesExcluded = $groupExcludedItems.Count

            if (
                $filesFailed -gt 0 -or
                $groupErrors.Count -gt 0
            ) {
                $groupStatus = 'CompletedWithErrors'
            }
            elseif ($filesSkipped -gt 0) {
                $groupStatus = 'CompletedWithWarnings'
            }
            else {
                $groupStatus = 'Success'
            }

            $firstItem = $groupItems[0]
            $lastItem  = $groupItems[-1]

            $components += [PSCustomObject]@{
                Component       = $group.Name
                SourcePath      = $firstItem.SourcePath
                DestinationPath = $firstItem.DestinationPath

                StartedAt       = $firstItem.StartedAt
                CompletedAt     = $lastItem.CompletedAt
                Duration        = (
                    $lastItem.CompletedAt -
                    $firstItem.StartedAt
                )

                FilesSelected   = [int]$filesSelected
                FilesCopied     = [int]$filesCopied
                FilesSkipped    = [int]$filesSkipped
                FilesExcluded   = [int]$filesExcluded
                FilesFailed     = [int]$filesFailed
                BytesCopied     = [int64]$bytesCopied

                Status          = $groupStatus

                SkippedItems    = @($groupSkippedItems)
                ExcludedItems   = @($groupExcludedItems)
                Errors          = @($groupErrors)
            }
        }
    }

    # Blocked, NotDetected and NothingToMigrate may have no CopyEngine
    # components. Reporting still needs one logical component.
    if ($components.Count -eq 0) {
        $components = @(
            [PSCustomObject]@{
                Component       = $ApplicationResult.ApplicationId
                SourcePath      = $ApplicationResult.SourceProfile
                DestinationPath = $ApplicationResult.DestinationProfile

                StartedAt       = $ApplicationResult.StartedAt
                CompletedAt     = $ApplicationResult.CompletedAt
                Duration        = $ApplicationResult.Duration

                FilesSelected   = $ApplicationResult.FilesSelected
                FilesCopied     = $ApplicationResult.FilesCopied
                FilesSkipped    = $ApplicationResult.FilesSkipped
                FilesExcluded   = $ApplicationResult.FilesExcluded
                FilesFailed     = $ApplicationResult.FilesFailed
                BytesCopied     = $ApplicationResult.BytesCopied

                Status          = $copyStatus

                SkippedItems    = @($ApplicationResult.SkippedItems)
                ExcludedItems   = @($normalizedExcludedItems)
                Errors          = @($normalizedErrors)
            }
        )
    }

    return [PSCustomObject]@{
        SourceProfile      = $ApplicationResult.SourceProfile
        DestinationProfile = $ApplicationResult.DestinationProfile

        StartedAt          = $ApplicationResult.StartedAt
        CompletedAt        = $ApplicationResult.CompletedAt
        Duration           = $ApplicationResult.Duration

        Status             = $copyStatus

        Totals             = [PSCustomObject]@{
            FilesSelected = $ApplicationResult.FilesSelected
            FilesCopied   = $ApplicationResult.FilesCopied
            FilesSkipped  = $ApplicationResult.FilesSkipped
            FilesExcluded = $ApplicationResult.FilesExcluded
            FilesFailed   = $ApplicationResult.FilesFailed
            BytesCopied   = $ApplicationResult.BytesCopied
        }

        Components         = @($components)
        SkippedItems       = @($ApplicationResult.SkippedItems)
        ExcludedItems      = @($normalizedExcludedItems)
        Errors             = @($normalizedErrors)
    }
}

Export-ModuleMember -Function @(
    'Test-ProfMigApplicationDefinition'
    'Get-ProfMigApplicationDefinitions'
    'Get-ProfMigApplicationDefinition'
    'Invoke-ProfMigApplicationMigration'
    'Get-ProfMigApplicationMigrationPlan'
    'ConvertTo-ProfMigApplicationCopyResult'
    'Test-ProfMigApplicationValidation'
    'Resolve-ProfMigApplicationPath'
    'Test-ProfMigApplicationDetection'
)