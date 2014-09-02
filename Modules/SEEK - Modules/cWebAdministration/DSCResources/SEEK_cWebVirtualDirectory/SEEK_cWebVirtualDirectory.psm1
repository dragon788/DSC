Import-Module WebAdministration

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Website,

        [System.String]
        $WebApplication = $null,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $virtualDirectoryName = Get-VirtualDirectoryName -Site $Website -Name $Name -Application $WebApplication
    $virtualDirectory = Get-WebVirtualDirectory -Site $Website -Application $WebApplication -Name $virtualDirectoryName

    if ($virtualDirectory.Count -eq 1)
    {
        return @{
            Name = $Name
            Website = $Website
            WebApplication = $WebApplication
            PhysicalPath = $virtualDirectory.PhysicalPath
            Ensure = "Present"
        }
    }

    return @{
        Name = $Name
        Website = $Website
        WebApplication = $WebApplication
        PhysicalPath = $null
        Ensure = "Absent"
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Website,

        [System.String]
        $WebApplication = $null,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $PhysicalPath,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    $virtualDirectory = Get-TargetResource -Website $Website -Name $Name -WebApplication $WebApplication

    if ($Ensure -eq "Present")
    {
        if ($virtualDirectory.Ensure -eq "Absent")
        {
            Write-Verbose "Creating new Web Virtual Directory $Name."
            New-WebVirtualDirectory -Site $Website -Application $WebApplication -Name $Name -PhysicalPath $PhysicalPath
        }
        else
        {
            Write-Verbose "Updating physical path for web virtual directory $Name."
            Set-ItemProperty -Path IIS:Sites\$Website\$WebApplication\$Name -Name physicalPath -Value $PhysicalPath
        }
    }

    if ($virtualDirectory.Ensure -eq "Present" -and $Ensure -eq "Absent")
    {
        Write-Verbose "Removing existing Virtual Directory $Name."
        Remove-WebVirtualDirectory -Site $Website -Application $WebApplication -Name $Name
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
        $Website,

        [System.String]
        $WebApplication = $null,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $PhysicalPath,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    Write-Verbose "Checking the virtual directories for the website."

    $virtualDirectory = Get-TargetResource -Website $Website -Name $Name -WebApplication $WebApplication

    if ($virtualDirectory.Ensure -eq "Absent" -and $Ensure -eq "Absent")
    {
        Write-Verbose "Web virtual direcotry $Name should be absent and is absent"
        return $true
    }

    if ($virtualDirectory.Ensure -eq "Present" `
        -and $Ensure -eq "Present" `
        -and $virtualDirectory.physicalPath -eq $PhysicalPath)
    {
        Write-Verbose "Web virtual directory is in required state"
        return $true
    }

    Write-Verbose "Web virtual directory $Name does not match desired state."

    return $false
}

function Get-VirtualDirectoryName
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Site,

        [System.String]
        $Application = $null
    )

    $virtualDirectoryName = $Name

    if ($Application -and -not (Test-ApplicationExists -Site $Site -Application $Application))
    {
        $virtualDirectoryName = Get-CompositeVirtualDirectoryName -Name $Name -Application $Application
    }

    return $virtualDirectoryName
}

function Test-ApplicationExists
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Site,

        [System.String]
        $Application = $null
    )
    $WebApplication = Get-WebApplication -Site $Site -Name $Application

    if ($WebApplication.count -eq 1)
    {
        return $true
    }

    Write-Warning "Specified Web Application $Application does not exist."

    return $false
}

function Get-CompositeVirtualDirectoryName
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Application
    )

    return "$Application/$Name"
}

Export-ModuleMember -Function *-TargetResource

