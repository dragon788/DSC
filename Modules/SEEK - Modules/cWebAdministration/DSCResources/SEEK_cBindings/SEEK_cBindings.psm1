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
        [System.String] $Site
    )

    get-BindingsResource (get-BindingConfigElements $Site) $Site
}

function Test-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String] $Site,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present",

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Bindings = @(),

        [System.Boolean]
        $Clear = $false
    )

    $currentCimBindings = get-CurrentCimBindings $Site
    $commonCimBindings = select-CommonCimBindings (new-CimBindingsWithBindingInformation $Bindings) $currentCimBindings

    if (($Ensure -eq "Absent") -and $Clear) { return (@($currentCimBindings).count -eq 0) -and (@($commonCimBindings).count -eq 0) }
    if ($Ensure -eq "Absent") { return @($commonCimBindings).count -eq 0 }

    if ($Clear) { return $currentCimBindings.count -eq $commonCimBindings.count }
    return (@($commonCimBindings).count -eq $Bindings.count)
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String] $Site,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present",

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Bindings = @(),

        [System.Boolean]
        $Clear = $false
    )



    $newCimBindings = new-CimBindingsForSite $Ensure $Bindings $Site $Clear
    $sitePath = $("IIS:\Sites\${Site}")
    Synchronized -Name "IIS" -ArgumentList $sitePath, (new-BindingsValue $newCimBindings) {
        param($path, $bindings)
        Set-ItemProperty -Path $path -Name bindings -Value $bindings
    }
    $newCimBindings | Where-Object Protocol -eq "https" | ForEach-Object { add-SslCertificateForHttpsCimBinding $_ }

    $protocols = $newCimBindings | Select-Object -ExpandProperty Protocol -Unique
    Synchronized -Name "IIS" -ArgumentList $sitePath, $protocols {
        param($path, $enabledProtocols)
        Set-ItemProperty $path -Name EnabledProtocols -Value ($enabledProtocols -join ',')
    }
}

function New-CimBinding
{
    [CmdletBinding()]
    param
    (
        [System.String] $BindingInformation,
        [System.String] $Protocol
    )

    New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property @{
        BindingInformation = $BindingInformation
        Protocol = $Protocol
    }
}

function New-HttpCimBinding {
    [CmdletBinding()]
    param
    (
        [System.String] $HostName,
        [System.String] $IPAddress,
        [System.UInt16] $Port
    )

    New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property @{
        HostName = $HostName
        IPAddress = $IPAddress
        Port = $Port
        Protocol = "http"
    }
}

function New-HttpsCimBinding {
    [CmdletBinding()]
    param
    (
        [System.String] $CertificatePath,
        [System.String] $CertificateSubject,
        [System.String] $IPAddress,
        [System.UInt16] $Port
    )

    New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property @{
        CertificatePath = $CertificatePath
        CertificateSubject = $CertificateSubject
        IPAddress = $IPAddress
        Port = $Port
        Protocol = "https"
    }
}

function add-SslCertificateForHttpsCimBinding
{
    [CmdletBinding()]
    param($httpsCimBinding)

    $ip = get-HttpSysIp $httpsCimBinding.IPAddress
    $path = $httpsCimBinding.CertificatePath
    $port = $httpsCimBinding.Port
    $thumbprint = get-CertificateThumbprint $httpsCimBinding

    $sslBindingPath = "IIS:\SslBindings\${ip}!${port}"

    if (Test-Path $sslBindingPath) {
        Write-Verbose "SSL binding for endpoint ${ip}:${port} alerady exists."
        Write-Verbose "Clobbering with new SSL binding."
        Remove-Item $sslBindingPath
    }

    Get-Item "${path}\${thumbprint}" | New-Item $sslBindingPath
}

function compare-CimBindings {
    [CmdletBinding()]
    param
    (
        $cimBinding,
        $otherCimBinding
    )

    $matchingBindingInformation = $cimBinding.BindingInformation -eq $otherCimBinding.BindingInformation
    $matchingProtocol = $cimBinding.Protocol -eq $otherCimBinding.Protocol

    if (-not ($matchingBindingInformation -and $matchingProtocol)) { return $false }

    $true
}

function containsCimBinding {
    [CmdletBinding()]
    param($bindings, $binding)

    $result = $false
    $bindings | ForEach-Object { if(compare-CimBindings $_ $binding) { $result = $true } }
    $result
}

function get-BindingConfigElements
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String] $Site
    )

    (Get-ItemProperty "IIS:\Sites\${Site}" -Name bindings)
}

function get-BindingInformation
{
    [CmdletBinding()]
    param($binding)

    if($binding.BindingInformation -ne $null) { return $binding.BindingInformation }

    switch ($binding.Protocol)
    {
        "http"
        { get-HttpBindingInformation $binding }
        "https"
        { get-HttpsBindingInformation $binding }
    }
}

function get-BindingsResource
{
    [CmdletBinding()]
    param($bindingConfigElements, $site)

    $result = @{
        Bindings = @()
        Ensure = "Absent"
        Site = $site
    }

    if($bindingConfigElements.count -ne 0) {
        $result.Bindings = new-CimBindingsFromConfigElements $bindingConfigElements
        $result.Ensure = "Present"
    }

    $result
}

function get-CertificateThumbprint
{
    [CmdletBinding()]
    param($httpsCimBinding)

    (Get-ChildItem -Path $httpsCimBinding.CertificatePath | Where Subject -eq $httpsCimBinding.CertificateSubject).Thumbprint
}

function get-CurrentCimBindings
{
    [CmdletBinding()]
    param($site)

    (Get-TargetResource -Site $site).Bindings
}

function get-HttpBindingInformation
{
    [CmdletBinding()]
    param($httpBinding)

    $hostName = $httpBinding.HostName
    $ipAddress = $httpBinding.IPAddress
    $port = $httpBinding.Port

    "${ipAddress}:${port}:${hostName}"
}

function get-HttpsBindingInformation
{
    [CmdletBinding()]
    param($httpsBinding)

    $ipAddress = $httpsBinding.IPAddress
    $port = $httpsBinding.Port

    "${ipAddress}:${port}:"
}

function get-HttpSysIp
{
    [CmdletBinding()]
    param($ip)

    if ($ip -eq "*") { return "0.0.0.0" }
    $ip
}

function new-CimBindingsForSite {
    [CmdletBinding()]
    param($ensure, $cimBindings, $site, $clear = $false)

    $currentCimBindings = @()

    if (!$clear) { $currentCimBindings = @(get-CurrentCimBindings $site) }

    if ($Ensure -eq "Absent") {
        return select-FromCimBindingsWithoutCimBindings -From $currentCimBindings -Without $cimBindings
    }

    $newBindings = $currentCimBindings
    $newBindings += $cimBindings
    return $newBindings
}

function new-BindingsValue
{
    [CmdletBinding()]
    param($bindings)

    (new-CimBindingsWithBindingInformation $bindings) | ForEach-Object {
        @{
            bindingInformation = $_.BindingInformation
            protocol = $_.Protocol
        }
    }
}

function new-CimBindingsWithBindingInformation
{
    [CmdletBinding()]
    param($cimBindings)

    $cimBindings | ForEach-Object {
        new-CimBindingFromHash @{
            BindingInformation = get-BindingInformation $_
            CertificatePath = $_.CertificatePath
            CertificateSubject = $_.CertificateSubject
            HostName = $_.HostName
            IPAddress = $_.IPAddress
            Port = $_.Port
            Protocol = $_.Protocol
        }
    }
}

function new-CimBindingFromConfigElement
{
    [CmdletBinding()]
    param($bindingConfigElement)

    $bindingHash = @{
        BindingInformation = $bindingConfigElement.bindingInformation
        Protocol = $bindingConfigElement.protocol
    }

    if ($bindingHash.Protocol -eq "https") {
        $bindingHash.CertificatePath = $bindingConfigElement.certificatePath
        $bindingHash.CertificateSubject = $bindingConfigElement.certificateSubject
    }

    new-CimBindingFromHash $bindingHash
}

function new-CimBindingsFromConfigElements
{
    [CmdletBinding()]
    param($bindingConfigElements)

    $bindingConfigElements.collection | ForEach-Object { new-CimBindingFromConfigElement $_ }
}

function new-CimBindingFromHash
{
    [CmdletBinding()]
    param($bindingHash)

    New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property (new-HashWithoutNullValues $bindingHash)
}

function new-HashWithoutNullValues
{
    [CmdletBinding()]
    param($hashtable)

    $result = @{}
    $hashtable.Keys | Where { $hashtable.$_ -ne $null } | ForEach { $result.$_ = ($hashtable.$_) }
    $result
}

function select-CommonCimBindings
{
    [CmdletBinding()]
    param($cimBindings, $otherCimBindings)

    $cimBindings | Where-Object { containsCimBinding $otherCimBindings $_ }
}

function select-FromCimBindingsWithoutCimBindings
{
    [CmdletBinding()]
    param($from, $without)

    $from | Where-Object { -not (containsCimBinding $without $_) }
}

function Confirm-Dependencies
{
    Write-Debug "Checking whether WebAdministration is there in the machine or not."
    if(!(Get-Module -ListAvailable -Name WebAdministration))
    {
        Throw "Please ensure that the WebAdministration module is installed."
    }
    Import-Module WebAdministration
}

Export-ModuleMember -Function *-TargetResource

