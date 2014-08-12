Import-Module WebAdministration

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
        $Bindings = @()
    )

    $presentBindings = select-CommonCimBindings (new-CimBindingsWithBindingInformation $Bindings) (get-CurrentCimBindings $Site)

    if ($Ensure -eq "Absent") {
        return @($presentBindings).count -eq 0
    }

    return (@($presentBindings).count -eq $Bindings.count)
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
        $Bindings = @()
    )

    $newCimBindings = new-CimBindingsForSite $Ensure $Bindings $Site
    Set-ItemProperty -Path "IIS:\Sites\${Site}" -Name bindings -Value (new-BindingsValue $newCimBindings)

    $newCimBindings | Where-Object Protocol -eq "https" | ForEach-Object {
        $ip = get-HttpSysIp $_.IPAddress
        $path = $_.CertificatePath
        $port = $_.Port
        $thumbprint = $_.CertificateThumbprint
        Get-Item "${path}\${thumbprint}" | New-Item "${ip}!${port}"
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
        [System.String] $CertificateThumbprint,
        [System.String] $CertificateStoreName,
        [System.String] $IPAddress,
        [System.UInt16] $Port
    )

    New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property @{
        CertificatePath = $CertificatePath
        CertificateThumbprint = $CertificateThumbprint
        CertificateStoreName = $CertificateStoreName
        IPAddress = $IPAddress
        Port = $Port
        Protocol = "https"
    }
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
    if ($cimBinding.Protocol -eq "https") { return compare-CimHttpsBindings $cimBinding $otherCimBinding }

    $true
}

function compare-CimHttpsBindings {
    [CmdletBinding()]
    param($cimHttpsBinding, $otherCimHttpsBinding)

    $cimHttpsBinding.CertificateStoreName -eq $otherCimHttpsBinding.CertificateStoreName -and
    $cimHttpsBinding.CertificateThumbprint -eq $otherCimHttpsBinding.CertificateThumbprint
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
    param($ensure, $cimBindings, $site)

    $currentCimBindings = @(get-CurrentCimBindings $site)

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
            CertificateStoreName = $_.CertificateStoreName
            CertificateThumbprint = $_.CertificateThumbprint
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
        $bindingHash.CertificateStoreName = $bindingConfigElement.certificateStoreName
        $bindingHash.CertificateThumbprint = $bindingConfigElement.certificateHash
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

Export-ModuleMember -Function *-TargetResource
