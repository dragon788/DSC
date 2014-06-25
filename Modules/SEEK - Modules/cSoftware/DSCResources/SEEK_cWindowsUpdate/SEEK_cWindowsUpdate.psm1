function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Update,

        [parameter(Mandatory = $true)]
        [System.String]
        $Kb
    )

    if (Test-UpdateInstalled($Kb))
    {
        return @{Update = $Update; Kb = $Kb; Ensure = "Present"}
    }

    return @{Update = $Update; Kb = $Kb; Ensure = "Absent"}
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Update,

        [parameter(Mandatory = $true)]
        [System.String]
        $Kb,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    $installed = Test-UpdateInstalled($Kb)

    if(($Ensure -eq "Present") -and ($installed -eq $false))
    {
        Install-Update -Update $Update
    }
    elseif (($Ensure -eq "Absent") -and ($installed -eq $true))
    {
        Uninstall-Update -Update $Update
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Update,

        [parameter(Mandatory = $true)]
        [System.String]
        $Kb,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    $installed = Test-UpdateInstalled($Kb)

    if ($Ensure -eq "Present")
    {
        return $installed
    }
    else
    {
        return !$installed
    }
}

function Test-UpdateInstalled
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Kb
    )

    $installed = Get-HotFix | Select-Object HotFixID | Select-String -Pattern $Kb -SimpleMatch -Quiet
    return ($installed -eq $true)
}

function Install-Update
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Update
    )

    Invoke-WindowsUpdateStandaloneInstaller -Update $Update
}

function Uninstall-Update
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Update
    )

    Invoke-WindowsUpdateStandaloneInstaller -Update $Update -Uninstall
}

function Invoke-WindowsUpdateStandaloneInstaller
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Update,

        [switch]
        $Uninstall = $false
    )

    $updateFile = $Update

    $updateArgs = @($updateFile, '/quiet', '/norestart')
    if($Uninstall)
    {
        $updateArgs = ,'/uninstall' + $updateArgs
    }

    Start-Process "${env:WINDIR}\system32\wusa.exe" -ArgumentList $updateArgs -Wait
}

Export-ModuleMember -Function *-TargetResource
