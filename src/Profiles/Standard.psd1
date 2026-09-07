@{
    SchemaVersion = '1.0'

    Profile = @{
        Name        = 'Standard'
        Description = 'Standard user migration profile.'
    }

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

       Include = @(
        'Microsoft.Edge'
        'Google.Chrome'
        'Microsoft.Outlook'
        )
    }

    Verification = @{
        Level = 'Standard'
    }
}