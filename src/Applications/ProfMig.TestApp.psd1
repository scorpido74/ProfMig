@{
    SchemaVersion = '1.0'

    Application = @{
        Id          = 'ProfMig.TestApp'
        Name        = 'ProfMig Test Application'
        Description = 'Test application for the ProfMig generic AppData migration framework.'
    }

    Detection = @(
        @{
            Type = 'PathExists'
            Root = 'APPDATA'
            Path = 'ProfMigTestApp'
        }
    )

    Migration = @(
        @{
            Name = 'RoamingData'

            Source = @{
                Root = 'APPDATA'
                Path = 'ProfMigTestApp'
            }

            Destination = @{
                Root = 'APPDATA'
                Path = 'ProfMigTestApp'
            }

            Include = @(
                '*.json'
                '*.xml'
                'Config\*'
            )

            Exclude = @(
                'credentials.json'
                'Cache\*'
                'Temp\*'
                '*.lock'
            )
        }

        @{
            Name = 'LocalData'

            Source = @{
                Root = 'LOCALAPPDATA'
                Path = 'ProfMigTestApp'
            }

            Destination = @{
                Root = 'LOCALAPPDATA'
                Path = 'ProfMigTestApp'
            }

            Include = @(
                'Settings\*'
            )

            Exclude = @(
                'Cache\*'
                'Logs\*'
                '*.lock'
            )
        }
    )

    Validation = @(
        @{
            Type = 'PathExists'
            Root = 'APPDATA'
            Path = 'ProfMigTestApp'
        }
    )
}