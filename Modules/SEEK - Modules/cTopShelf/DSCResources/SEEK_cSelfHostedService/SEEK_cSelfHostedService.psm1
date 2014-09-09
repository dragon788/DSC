function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Name
    )

    $service = Get-Service $Name -ErrorAction Ignore

    if ($service) {
        return @{
            Name = $Name
            Ensure = "Present"
        }
    }

    return @{
        Name = $Name
        Ensure = "Absent"
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Name,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Executable,

        [ValidateSet("true", "false")]
        [String]$Start = "false",

        [ValidateSet("true", "false")]
        [String]$AutoStart = "true",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    if ($Ensure -eq "Present")
    {
        $argumentList = @('install', "-servicename:$Name")

        if ($Start -eq "true") { $argumentList += @('start')}
        if ($AutoStart -eq "true") { $argumentList += @('--autostart')}
    }
    else
    {
        $argumentList = @('uninstall', "-servicename:$Name")
    }

    $process = Start-Process $Executable -ArgumentList $argumentList -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -ne 0) { throw "Error running top shelf executable ""$executable $($argumentList -join ' ')""" }
}

function Test-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Name,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Executable,

        [ValidateSet("true", "false")]
        [String]$Start = "false",

        [ValidateSet("true", "false")]
        [String]$AutoStart = "true",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    return $false
}


Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource
