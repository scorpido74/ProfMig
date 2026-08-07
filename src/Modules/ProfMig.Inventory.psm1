function Get-UserProfiles {

    $Users = Get-ChildItem "C:\Users" -Directory |
        Where-Object {

            $_.Name -notin $Global:Config.ExcludedProfiles

        } |
        Sort-Object Name

    return $Users

}

Export-ModuleMember -Function *