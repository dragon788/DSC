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
        [System.String]$Website,

        [parameter(Mandatory = $true)]
        [System.String]$Name
    )

    $webApplication = Find-UniqueWebApplication -Site $Website -Name $Name
    if ($webApplication -ne $null)
    {
        return @{
            Website = $Website
            Name = $Name
            WebAppPool = $webApplication.ApplicationPool
            PhysicalPath = $webApplication.PhysicalPath
            Ensure = "Present"
            AuthenticationInfo = Get-AuthenticationInfo -Website $Website -ApplicationName $Name
            SslFlags = (Get-SslFlags -Location "${Website}/${Name}")
            EnabledProtocols = (Get-ItemProperty "IIS:\Sites\${Website}\${Name}" -Name "EnabledProtocols").Value
        }
    }

    return @{
        Website = $Website
        Name = $Name
        WebAppPool = $null
        PhysicalPath = $null
        Ensure = "Absent"
        AuthenticationInfo = $null
        SslFlags = $null
        EnabledProtocols = $null
    }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Website,

        [parameter(Mandatory = $true)]
        [System.String]$Name,

        [parameter(Mandatory = $true)]
        [System.String]$WebAppPool,

        [parameter(Mandatory = $true)]
        [System.String]$PhysicalPath,

        [ValidateNotNull()]
        [string]$SslFlags = "",

        [ValidateSet("Present","Absent")]
        [System.String]$Ensure = "Present",

        [System.String] $EnabledProtocols,

        [Parameter(Mandatory=$false, HelpMessage="Obsolete")]
        [System.String] $AutoStartMode,

        [Microsoft.Management.Infrastructure.CimInstance]$AuthenticationInfo
    )

    if ($AuthenticationInfo -eq $null) { $AuthenticationInfo = Get-DefaultAuthenticationInfo }

    $webApplication = Find-UniqueWebApplication -Site $Website -Name $Name
    $webappPath = "IIS:\Sites\${Website}\${Name}"
    if ($Ensure -eq "Present")
    {

        if ($webApplication -eq $null)
        {
            Write-Verbose "Creating new Web application $Name."
            New-WebApplication -Site $Website -Name $Name -PhysicalPath $PhysicalPath -ApplicationPool $WebAppPool
        }
        else
        {
            if ($webApplication.physicalPath -ne $PhysicalPath)
            {
                Write-Verbose "Updating physical path for Web application $Name."
                Synchronized -Name "IIS" -ArgumentList $webappPath, $physicalPath -ScriptBlock {
                    param($path, $physicalPath)
                    Set-ItemProperty -Path $path -Name physicalPath -Value $physicalPath
                }
            }
            if ($webApplication.applicationPool -ne $ApplicationPool)
            {
                Write-Verbose "Updating physical path for Web application $Name."
                Synchronized -Name "IIS" -ArgumentList $webappPath, $WebAppPool -ScriptBlock {
                    param($path, $applicationPool)
                    Set-ItemProperty -Path $path -Name applicationPool -Value $applicationPool
                }
            }
        }

        Set-AuthenticationInfo -Website $Website -ApplicationName $Name -AuthenticationInfo $AuthenticationInfo -ErrorAction Stop
        Set-WebConfiguration -Location "${Website}/${Name}" -Filter 'system.webserver/security/access' -Value $SslFlags

        if ($EnabledProtocols) {
            Synchronized -Name "IIS" -ArgumentList $webappPath, $EnabledProtocols -ScriptBlock {
                param($path, $enabledProtocols)
                Set-ItemProperty -Path $path -Name EnabledProtocols -Value $enabledProtocols
            }
        }
    }
    elseif (($Ensure -eq "Absent") -and ($webApplication -ne $null))
    {
        Write-Verbose "Removing existing Web Application $Name."
        Remove-WebApplication -Site $Website -Name $Name
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Website,

        [parameter(Mandatory = $true)]
        [System.String]$Name,

        [parameter(Mandatory = $true)]
        [System.String]$WebAppPool,

        [parameter(Mandatory = $true)]
        [System.String]$PhysicalPath,

        [ValidateNotNull()]
        [string]$SslFlags = "",

        [ValidateSet("Present","Absent")]
        [System.String]$Ensure = "Present",

        [System.String] $EnabledProtocols,

        [Parameter(Mandatory=$false, HelpMessage="Obsolete")]
        [System.String] $AutoStartMode,

        [Microsoft.Management.Infrastructure.CimInstance]$AuthenticationInfo
    )

    if ($AuthenticationInfo -eq $null) { $AuthenticationInfo = Get-DefaultAuthenticationInfo }

    $webApplication = Get-TargetResource -Website $Website -Name $Name

    if($Ensure -eq "Present")
    {
        $enabledProtocolsMatch = if ($EnabledProtocols) { $webApplication.EnabledProtocols -eq $EnabledProtocols } else { $true }

        if(($webApplication.Ensure -eq $Ensure) `
            -and ($webApplication.PhysicalPath -eq $PhysicalPath) `
            -and ($webApplication.WebAppPool -eq $WebAppPool) `
            -and ((Get-SslFlags -Location "${Website}/${Name}") -eq $SslFlags) `
            -and (Test-AuthenticationInfo -Website $Website -ApplicationName $Name -AuthenticationInfo $AuthenticationInfo) `
            -and $enabledProtocolsMatch)
        {
            return $true
        }
    }
    elseif($webApplication.Ensure -eq $Ensure)
    {
        return $true
    }

    return $false
}

function Find-UniqueWebApplication
{
    Param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Site,

        [parameter(Mandatory = $true)]
        [System.String]$Name
    )

    $webApplications = @(Get-WebApplication -Site $Site -Name $Name)

    if ($webApplications.Count -gt 1)
    {
        throw "Multiple web applications found for ""${Site}/${Name}"""
    }

    return $webApplications[0]
}

function Test-AuthenticationEnabled
{
    [OutputType([System.Boolean])]
    Param
    (
        [parameter(Mandatory = $true)]
        [System.String]$WebSite,

        [parameter(Mandatory = $true)]
        [System.String]$ApplicationName,

        [parameter(Mandatory = $true)]
        [ValidateSet("Anonymous","Basic","Digest","Windows")]
        [System.String]$Type
    )


    $prop = Get-WebConfigurationProperty `
        -Filter /system.WebServer/security/authentication/${Type}Authentication `
        -Name enabled `
        -Location "${WebSite}/${ApplicationName}"
    return $prop.Value
}

function Set-Authentication
{
    Param
    (
        [parameter(Mandatory = $true)]
        [System.String]$WebSite,

        [parameter(Mandatory = $true)]
        [System.String]$ApplicationName,

        [parameter(Mandatory = $true)]
        [ValidateSet("Anonymous","Basic","Digest","Windows")]
        [System.String]$Type,

        [System.Boolean]$Enabled
    )

    Set-WebConfigurationProperty -Filter /system.WebServer/security/authentication/${Type}Authentication `
        -Name enabled `
        -Value $Enabled `
        -Location "${WebSite}/${Name}"
}

function Get-AuthenticationInfo
{
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    Param
    (
        [parameter(Mandatory = $true)]
        [System.String]$WebSite,

        [parameter(Mandatory = $true)]
        [System.String]$ApplicationName
    )

    $authenticationProperties = @{}
    foreach ($type in @("Anonymous", "Basic", "Digest", "Windows"))
    {
        $authenticationProperties[$type] = [string](Test-AuthenticationEnabled -Website $Website -ApplicationName $Name -Type $type)
    }

    return New-CimInstance -ClassName SEEK_cWebAuthenticationInformation -ClientOnly -Property $authenticationProperties
}

function Test-AuthenticationInfo
{
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Website,

        [parameter(Mandatory = $true)]
        [System.String]$ApplicationName,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]$AuthenticationInfo
    )

    $result = $true

    foreach ($type in @("Anonymous", "Basic", "Digest", "Windows"))
    {

        $expected = $AuthenticationInfo.CimInstanceProperties[$type].Value
        $actual = Test-AuthenticationEnabled -Website $Website -ApplicationName $ApplicationName -Type $type
        if ($expected -ne $actual)
        {
            $result = $false
            break
        }
    }

    return $result
}

function Set-AuthenticationInfo
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$WebSite,

        [parameter(Mandatory = $true)]
        [System.String]$ApplicationName,

        [parameter()]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]$AuthenticationInfo
    )

    foreach ($type in @("Anonymous", "Basic", "Digest", "Windows"))
    {
        $enabled = ($AuthenticationInfo.CimInstanceProperties[$type].Value -eq $true)
        Set-Authentication -Website $Website -ApplicationName $ApplicationName -Type $type -Enabled $enabled
    }
}

function Get-DefaultAuthenticationInfo
{
    New-CimInstance -ClassName SEEK_cWebAuthenticationInformation `
        -ClientOnly `
        -Property @{Anonymous="false";Basic="false";Digest="false";Windows="false"}
}

function Get-SslFlags
{
    [CmdletBinding()]
    param
    (
        [System.String]$Location
    )

    $sslFlags = Get-WebConfiguration -PSPath IIS:\Sites -Location $Location -Filter 'system.webserver/security/access' | % { $_.sslFlags }
    $sslFlags = if ($sslFlags -eq $null) { "" } else { $sslFlags }
    return $sslFlags
}

Export-ModuleMember -Function *-TargetResource

