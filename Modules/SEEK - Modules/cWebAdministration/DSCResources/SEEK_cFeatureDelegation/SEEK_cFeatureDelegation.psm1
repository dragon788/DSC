function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Section
    )

    $configuration = Get-WebConfiguration -Filter $Section -PSPath "IIS:"

    if($configuration -ne $null -and $configuration.OverrideMode -eq "Allow") {
        return @{
            Ensure = "Present"
            Section = $Section
        }
    }

    return @{Ensure = "Absent"}
}

function Test-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Section,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    $actualState = Get-TargetResource -Section $Section

    if ($Ensure -eq $actualState.Ensure) { return $true }

    return $false
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Section,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    if($Ensure -eq "Absent") {
        $overrideMode = "Deny"
    } 
    else {
        $overrideMode = "Allow"
    }

    Set-WebConfiguration -Filter $Section -PSPath "IIS:" -MetaData "overrideMode" -Value $overrideMode
}

Export-ModuleMember -Function *-TargetResource
