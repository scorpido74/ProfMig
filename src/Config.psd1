@{
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