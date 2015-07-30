$LogonMethodEnum = @("Batch","Interactive","Network","ClearText")

function Synchronized
{
    [CmdletBinding()]
    param
    (
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[^\\]?")]
        [parameter(Mandatory = $true)]
        [string] $Name,

        [parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,

        [parameter(Mandatory = $false)]
        [int] $MillisecondsTimeout = 5000,

        [parameter(Mandatory = $false)]
        [boolean] $InitiallyOwned = $false,

        [parameter(Mandatory = $false)]
        [Object[]] $ArgumentList = @(),

        [parameter(Mandatory = $false)]
        [ValidateSet("Global","Local","Session")]
        [Object[]] $Scope = "Global"
    )

    Confirm-Dependencies

    $mutex = New-Object System.Threading.Mutex($InitiallyOwned, "${Scope}\${Name}")

    if ($mutex.WaitOne($MillisecondsTimeout)) {
        try {
            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        }
        finally {
            $mutex.ReleaseMutex()
        }
    }
    else { throw "Cannot aquire mutex: $Name"}
}

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

    Confirm-Dependencies

    if (test-VirtualDirectoryExists $WebSite $Name $WebApplication)
    {
        $virtualDirectoryPath = Get-VirtualDirectoryPath -Site $Website -Name $Name -Application $WebApplication
        $virtualDirectory = Get-Item -Path $virtualDirectoryPath
        return @{
            Name = $Name
            Website = $Website
            WebApplication = $WebApplication
            PhysicalPath = $virtualDirectory.PhysicalPath
            LogonMethod = $virtualDirectory.logonMethod
            Username = $virtualDirectory.username
            Password = $virtualDirectory.password
            Ensure = "Present"
        }
    }

    return @{
        Name = $Name
        Website = $Website
        WebApplication = $WebApplication
        PhysicalPath = $null
        LogonMethod = $null
        Username = $null
        Password = $null
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

        [ValidateSet("Batch","Interactive","Network","ClearText")]
        [System.String]
        $LogonMethod = "ClearText",

        [System.String]
        $Username = "",

        [System.String]
        $Password = "",


        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    Confirm-Dependencies

    $virtualDirectory = Get-TargetResource -Website $Website -Name $Name -WebApplication $WebApplication

    if ($Ensure -eq "Present")
    {
        $path = Get-VirtualDirectoryPath -Site $Website -Application $WebApplication -Name $Name

        if ($virtualDirectory.Ensure -eq "Absent")
        {
            Write-Verbose "Creating new Web Virtual Directory $Name."
            New-WebVirtualDirectory -Site $Website -Application $WebApplication -Name $Name -PhysicalPath $PhysicalPath
        }
        else
        {
            Write-Verbose "Updating physical path for web virtual directory $Name."
            Synchronized -Name "IIS" -ArgumentList $path, $PhysicalPath {
                param($path, $physicalPath)
                Set-ItemProperty -Path $path -Name physicalPath -Value $physicalPath
            }
        }

        Synchronized -Name "IIS" -ArgumentList $path, ($LogonMethodEnum.IndexOf($LogonMethod)) {
            param($path, $logonMethod)
            Set-ItemProperty -Path $path -Name logonMethod -Value $logonMethod
        }

         Synchronized -Name "IIS" -ArgumentList $path, $Username, $Password {
            param($path, $username, $password)
            Set-ItemProperty -Path $path -Name username -Value $username
            Set-ItemProperty -Path $path -Name password -Value $password
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

        [ValidateSet("ClearText","Network","Interactive","Batch")]
        [System.String]
        $LogonMethod = "ClearText",

        [System.String]
        $Username = "",

        [System.String]
        $Password = "",

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
        -and $virtualDirectory.physicalPath -eq $PhysicalPath `
        -and $virtualDirectory.logonMethod -eq $LogonMethod `
        -and $virtualDirectory.username -eq $Username `
        -and $virtualDirectory.password -eq $Password)
    {
        Write-Verbose "Web virtual directory is in required state"
        return $true
    }

    Write-Verbose "Web virtual directory $Name does not match desired state."

    return $false
}

function Get-VirtualDirectoryPath
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

    if (-not $Application)
    {
        return "IIS:\Sites\${Site}\${Name}"
    }

    return "IIS:\Sites\${Site}\${Application}\${Name}"
}

function test-VirtualDirectoryExists
{
    param
    (
        [System.String] $Website,
        [System.String] $Name,
        [System.String] $WebApplication
    )

    $virtualDirectoryPath = Get-VirtualDirectoryPath -Site $Website -Name $Name -Application $WebApplication

    if(-not (Test-Path $virtualDirectoryPath)) { return $false}

    $virtualDirectory = Get-Item -Path $virtualDirectoryPath

    $virtualDirectory.PhysicalPath -ne $null
}

function Confirm-Dependencies
{
    Write-Verbose "Checking whether WebAdministration is there in the machine or not."
    if(!(Get-Module -ListAvailable -Name WebAdministration))
    {
        Throw "Please ensure that the WebAdministration module is installed."
    }
}

Export-ModuleMember -Function *-TargetResource

