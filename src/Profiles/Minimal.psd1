@{
    SchemaVersion = '1.0'

    Profile = @{
        Name        = 'Minimal'
        Description = 'Minimal user migration profile.'
    }

    Components = @(
        'Desktop'
        'Documents'
    )

    Applications = @{
        Enabled = $false

        Include = @()
    }

    Verification = @{
        Level = 'Standard'
    }
}