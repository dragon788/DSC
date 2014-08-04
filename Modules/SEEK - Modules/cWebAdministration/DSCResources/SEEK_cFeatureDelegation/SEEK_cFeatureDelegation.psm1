Import-Module WebAdministration

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Name
    )

    $configuration = Get-WebConfiguration -Filter "//${Name}" -PSPath "IIS:"
    if ($configuration -eq $null) { return @{Ensure = "Absent"} }

    return @{
        Ensure = "Present"
        Name = $Name
        OverrideMode = $configuration.OverrideMode
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Allow","Deny","Inherit")]
        [System.String]
        $OverrideMode,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    $actualState = Get-TargetResource -Name $Name

    if ($Ensure -eq "Absent" -and $Ensure -eq $actualState.Ensure) { return $true }

    if ($OverrideMode -eq $actualState.OverrideMode -and
        $Ensure -eq $actualState.Ensure)
    {
        return $true
    }

    return $false
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Allow","Deny","Inherit")]
        [System.String]
        $OverrideMode = "Inherit",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    if($Ensure -eq "Absent") {
        $OverrideMode = "Inherit"
    }

    Set-WebConfiguration -Filter "//${Name}" -PSPath "IIS:" -MetaData "overrideMode" -Value $OverrideMode
}

Export-ModuleMember -Function *-TargetResource