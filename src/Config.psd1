@{
    SchemaVersion = '1.0'

    Application = @{
        Name    = 'ProfMig'
        Version = '0.2.0'
        Build   = 'Development'
    }

    Paths = @{
        Logs                   = 'Logs'
        Reports                = 'Reports'
        Backup                 = 'Backup'
        ApplicationDefinitions = 'Applications'
        MigrationProfiles      = 'Profiles'
    }

    Migration = @{
        DefaultProfile = 'Standard'

        Components = @(
            'Desktop'
            'Documents'
            'Downloads'
            'Pictures'
            'Music'
            'Videos'
            'Favorites'
            'Links'
        )

        Applications = @{
            Enabled = $true
        }
    }

    Retry = @{
        Count        = 3
        DelaySeconds = 2
    }

    Validation = @{
        Storage = @{
            SafetyMarginPercent     = 20
            WarningRemainingPercent = 15
        }
    }

    Verification = @{
        Level         = 'Standard'
        HashAlgorithm = 'SHA256'
    }

      ExcludedProfiles = @(
        'All Users'
        'Default'
        'Default User'
        'Public'
        'defaultuser0'
        'WDAGUtilityAccount'
        'Administrator'
        'systemprofile'
        'LocalService'
        'NetworkService'
    )
}
