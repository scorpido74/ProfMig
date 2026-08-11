@{
    Application = @{
        Name    = 'ProfMig'
        Version = '1.0'
        Build   = 'Development'
    }

    Paths = @{
        Logs    = 'Logs'
        Reports = 'Reports'
        Backup  = 'Backup'
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