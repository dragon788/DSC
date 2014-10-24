function Get-ASApplication
{
    param ($SiteName, $VirtualPath)
}

function Set-ASApplication
{
    param ($SiteName, $VirtualPath, $AutoStartMode, [switch]EnableApplicationPool)
}

Export-ModuleMember Get-ASApplication, Set-ASApplication