function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Website,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $WebAppPool,

        [parameter(Mandatory = $true)]
        [System.String]
        $PhysicalPath
    )

    CheckDependencies

    $webApplication = Get-WebApplication -Site $Website -Name $Name

    $PhysicalPath = ""
    $Ensure = "Absent"
    $WebAppPool = ""

    if ($webApplication.Count -eq 1)
    {
        $PhysicalPath = $webApplication.PhysicalPath
        $WebAppPool = $webApplication.applicationPool
        $Ensure = "Present"

        $AnonymousAuthentication = Get-WebConfigurationProperty -filter /system.WebServer/security/authentication/AnonymousAuthentication -Name enabled -Location $Name
        $BasicAuthentication = Get-WebConfigurationProperty -filter /system.WebServer/security/authentication/BasicAuthentication -Name enabled -Location $Name
        $DigestAuthentication = Get-WebConfigurationProperty -filter /system.WebServer/security/authentication/DigestAuthentication -Name enabled -Location $Name
        $WindowsAuthentication = Get-WebConfigurationProperty -filter /system.WebServer/security/authentication/WindowsAuthentication -Name enabled -Location $Name

        $CimAuthentication =
        {
            New-CimInstance -ClassName SEEK_cWebAuthenticationInformation -Namespace root/microsoft/Windows/DesiredStateConfiguration -Property @{Anonymous=$AnonymousAuthentication;Basic=$BasicAuthentication;Digest=$DigestAuthentication;Windows=$WindowsAuthentication}
        }
    }

    $returnValue = @{
        Website = $Website
        Name = $Name
        WebAppPool = $WebAppPool
        PhysicalPath = $PhysicalPath
        Ensure = $Ensure
        AuthenticationInfo = $CimAuthentication
    }

    return $returnValue
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Website,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $WebAppPool,

        [parameter(Mandatory = $true)]
        [System.String]
        $PhysicalPath,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [Microsoft.Management.Infrastructure.CimInstance]$AuthenticationInfo
    )

    CheckDependencies

    if ($Ensure -eq "Present")
    {
        $webApplication = Get-WebApplication -Site $Website -Name $Name
        if ($webApplication.count -eq 0)
        {
            Write-Verbose "Creating new Web application $Name."
            New-WebApplication -Site $Website -Name $Name -PhysicalPath $PhysicalPath -ApplicationPool $WebAppPool

            #Update Authentication settings if required
            if ($AuthenticationInfo -ne $null)
            {
                if(ValidateWebsiteAuthentication -Name "$Website/$Name" -AuthenticationInfo $AuthenticationInfo)
                {
                    $UpdateNotRequired = $false
                    #Update Authentication
                    UpdateAuthentication -Name "$Website/$Name" -AuthenticationInfo $AuthenticationInfo -ErrorAction Stop

                    Write-Verbose("Authentication for website $Name have been updated.");
                }
            }
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

            #Update Authentication settings if required
            if ($AuthenticationInfo -ne $null)
            {
                Write-Verbose ("Validate Authentication information update for website $Name")
                if(ValidateWebsiteAuthentication -Name "$Website/$Name" -AuthenticationInfo $AuthenticationInfo)
                {
                    #Update Authentication
                    UpdateAuthentication -Name "$Website/$Name" -AuthenticationInfo $AuthenticationInfo -ErrorAction Stop

                    Write-Verbose ("Authentication information for website $Name updated")
                }
            }
        }
    }

    if ($Ensure -eq "Absent")
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
        [System.String]
        $Website,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $WebAppPool,

        [parameter(Mandatory = $true)]
        [System.String]
        $PhysicalPath,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [Microsoft.Management.Infrastructure.CimInstance]$AuthenticationInfo
    )

    CheckDependencies

    $webApplication = Get-WebApplication -Site $Website -Name $Name

    if ($webApplication.count -eq 1 -and $Ensure -eq "Present") {
        if ($webApplication.physicalPath -ne $PhysicalPath)
        {
            Write-Verbose "Physical path for web application $Name does not match desired state."
            return $false
        }
        elseif ($webApplication.applicationPool -ne $WebAppPool)
        {
            Write-Verbose "Web application pool for web application $Name does not match desired state."
            return $false
        }
        else
        {
            Write-Verbose "Web application pool matches desired state."
            return $true
        }

        #Check Authentication properties
        if($AuthenticationInfo -ne $null)
        {
            if(ValidateWebsiteAuthentication -Name "$Website/$Name" -AuthenticationInfo $AuthenticationInfo)
            {
                $DesiredConfigurationMatch = $false
                Write-Verbose("Authentication for website $Name do not mach the desired state.");
                break
            }
        }
    }

    if ($webApplication.count -eq 0 -and $Ensure -eq "Absent") {
        Write-Verbose "Web application $Name should be absent and is absent."
        return $true
    }

    return $false
}

# Returns true if authentication settings is valid
function ValidateWebsiteAuthentication
{
    Param
    (
        # website name
        [parameter()]
        [string]
        $Name,

        [parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $AuthenticationInfo
    )

    return compareWebsiteAuthentication -Name $Name -AuthenticationInfo $AuthenticationInfo
}

function compareWebsiteAuthentication
{
    param
    (
        [parameter()]
        [string]
        $Name,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $AuthenticationInfo
    )
    #Assume authenticationNeedUpdating
    $AuthenticationNeedsUpdating = $false

    try
    {
        $ActualAnonymousAuthentication = Get-WebConfigurationProperty -filter /system.WebServer/security/authentication/AnonymousAuthentication -Name enabled -Location $Name
        $ActualBasicAuthentication = Get-WebConfigurationProperty -filter /system.WebServer/security/authentication/BasicAuthentication -Name enabled -Location $Name
        $ActualDigestAuthentication = Get-WebConfigurationProperty -filter /system.WebServer/security/authentication/DigestAuthentication -Name enabled -Location $Name
        $ActualWindowsAuthentication = Get-WebConfigurationProperty -filter /system.WebServer/security/authentication/WindowsAuthentication -Name enabled -Location $Name

        Write-Verbose("Actual Anonymous = $ActualAnonymousAuthentication")
        Write-Verbose("Actual Basic = $ActualBasicAuthentication")
        Write-Verbose("Actual Digest = $ActualDigestAuthentication")
        Write-Verbose("Actual Windows = $ActualWindowsAuthentication")


        if ($ActualAnonymousAuthentication -ne [string]$AuthenticationInfo.CimInstanceProperties["Anonymous"].Value)
        {
            $AuthenticationNeedsUpdating = $true
        }
        elseif ($ActualBasicAuthentication -ne [string]$AuthenticationInfo.CimInstanceProperties["Basic"].Value)
        {
            $AuthenticationNeedsUpdating = $true
        }
        elseif ($ActualDigestAuthentication -ne [string]$AuthenticationInfo.CimInstanceProperties["Digest"].Value)
        {
            $AuthenticationNeedsUpdating = $true
        }
        elseif ($ActualWindowsAuthentication -ne [string]$AuthenticationInfo.CimInstanceProperties["Windows"].Value)
        {
            $AuthenticationNeedsUpdating = $true
        }

        return $AuthenticationNeedsUpdating
    }
    catch
    {
        $errorId = "WebsiteAuthenticationCompareFailure";
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult
        $errorMessage = $($LocalizedData.WebsiteCompareFailureError) -f ${Name}
        $exception = New-Object System.InvalidOperationException $errorMessage
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord);
    }
}


function UpdateAuthentication
{
    param
    (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $AuthenticationInfo
    )

    $AnonymousAuthentication = $AuthenticationInfo.CimInstanceProperties["Anonymous"].Value
    $BasicAuthentication = $AuthenticationInfo.CimInstanceProperties["Basic"].Value
    $DigestAuthentication = $AuthenticationInfo.CimInstanceProperties["Digest"].Value
    $WindowsAuthentication = $AuthenticationInfo.CimInstanceProperties["Windows"].Value

    if ($AnonymousAuthentication -ne $null)
    {
        Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/AnonymousAuthentication -Name enabled -Value $AnonymousAuthentication -Location $Name
    }

    if ($BasicAuthentication -ne $null)
    {
        Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/BasicAuthentication -Name enabled -Value $BasicAuthentication -Location $Name
    }

    if ($DigestAuthentication -ne $null)
    {
        Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/DigestAuthentication -Name enabled -Value $DigestAuthentication -Location $Name
    }

    if ($WindowsAuthentication -ne $null)
    {
        Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/WindowsAuthentication -Name enabled -Value $WindowsAuthentication -Location $Name
    }
}

function CheckDependencies
{
    Write-Verbose "Checking whether WebAdministration is there in the machine or not."
    # Check if WebAdministration module is present for IIS cmdlets
    if(!(Get-Module -ListAvailable -Name WebAdministration))
    {
        Throw "Please ensure that WebAdministration module is installed."
    }
}

Export-ModuleMember -Function *-TargetResource

