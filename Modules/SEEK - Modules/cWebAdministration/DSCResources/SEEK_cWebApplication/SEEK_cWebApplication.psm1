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

    CheckDependencies

    $webApplication = Find-UniqueWebApplication -Site $Website -Name $Name
    if ($webApplication)
    {
        return @{
            Website = $Website
            Name = $Name
            WebAppPool = $webApplication.ApplicationPool
            PhysicalPath = $webApplication.PhysicalPath
            Ensure = "Present"
            AuthenticationInfo = Get-AuthenticationInfo -Website $Website -ApplicationName $Name
        }
    }

    return @{
        Website = $Website
        Name = $Name
        WebAppPool = $null
        PhysicalPath = $null
        Ensure = "Absent"
        AuthenticationInfo = $null
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

        [ValidateSet("Present","Absent")]
        [System.String]$Ensure = "Present",

        [Microsoft.Management.Infrastructure.CimInstance]$AuthenticationInfo
    )

    CheckDependencies


    if ($AuthenticationInfo -eq $null) { $AuthenticationInfo = Get-DefaultAuthenticationInfo }

    $webApplication = Find-UniqueWebApplication -Site $Website -Name $Name
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
                Set-ItemProperty -Path IIS:Sites\$Website\$Name -Name physicalPath -Value $PhysicalPath
            }
            if ($webApplication.applicationPool -ne $ApplicationPool)
            {
                Write-Verbose "Updating physical path for Web application $Name."
                Set-ItemProperty -Path IIS:Sites\$Website\$Name -Name applicationPool -Value $WebAppPool
            }
        }

        Set-AuthenticationInfo -Website $Website -ApplicationName $Name -AuthenticationInfo $AuthenticationInfo -ErrorAction Stop
    }

    if ($webApplication -and ($Ensure -eq "Absent"))
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

        [ValidateSet("Present","Absent")]
        [System.String]$Ensure = "Present",

        [Microsoft.Management.Infrastructure.CimInstance]$AuthenticationInfo
    )

    CheckDependencies

    if ($AuthenticationInfo -eq $null) { $AuthenticationInfo = Get-DefaultAuthenticationInfo }

    $webApplication = Get-TargetResource -Website $Website -Name $Name

    if($Ensure -eq "Present")
    {
        if(($webApplication.Ensure -eq $Ensure) `
            -and ($webApplication.PhysicalPath -eq $PhysicalPath) `
            -and ($webApplication.WebAppPool -eq $WebAppPool) `
            -and (Test-AuthenticationInfo -Website $Website -ApplicationName $Name -AuthenticationInfo $AuthenticationInfo))
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

    if ($webApplications -gt 1)
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
        -Location "${WebSite}/${Name}"
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
        $enabled = [boolean]$AuthenticationInfo.CimInstanceProperties[$type].Value
        Set-Authentication -Website $Website -ApplicationName $ApplicationName -Type $type -Enabled $enabled
    }
}

function Get-DefaultAuthenticationInfo
{
    New-CimInstance -ClassName SEEK_cWebAuthenticationInformation `
        -ClientOnly `
        -Property @{Anonymous="false";Basic="false";Digest="false";Windows="false"}
}

function CheckDependencies
{
    Write-Verbose "Checking whether WebAdministration module is available."
    if(!(Get-Module -ListAvailable -Name WebAdministration))
    {
        Throw "Please ensure that WebAdministration module is installed."
    }
}

Export-ModuleMember -Function *-TargetResource

