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

    get-BindingsResource (get-BindingProperty $Site) $Site
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

    $presentBindings = select-CommonBindings (new-BindingsWithBindingInformation $Bindings) (get-CurrentBindings $Site)

    if ($Ensure -eq "Absent") {
        return @($presentBindings).count -eq 0
    }

    return @($presentBindings).count -eq $Bindings.count
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

    Set-ItemProperty -Path "IIS:\Sites\${Site}" -Name bindings -Value (new-BindingsValue (new-BindingsForSite $Ensure $Bindings $Site))
}

function compare-Bindings {
    [CmdletBinding()]
    param($bindingOne, $bindingTwo)

    $matchingBindingInformation = $bindingOne.BindingInformation -eq $bindingTwo.BindingInformation
    $matchingProtocol = $bindingOne.Protocol -eq $bindingTwo.Protocol
    return $matchingBindingInformation -and $matchingProtocol
}

function containsBinding {
    [CmdletBinding()]
    param($bindings, $binding)

    $bindings | ForEach-Object {
        if(compare-Bindings $_ $binding) { return $true }
    }

    $false
}

function get-BindingInformation {
    [CmdletBinding()]
    param($binding)

    $bindingInformation = $binding.BindingInformation

    if($bindingInformation -eq $null -and $binding.Protocol -eq "http") {
        $bindingInformation = get-HttpBindingInformation $binding
    }

    $bindingInformation
}

function get-BindingProperty
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String] $Site
    )

    (Get-ItemProperty "IIS:\Sites\${Site}" -Name bindings)
}

function get-BindingsResource {
    [CmdletBinding()]
    param($bindings, $site)

    $result = @{
        Bindings = @()
        Ensure = "Absent"
        Site = $site
    }

    if($bindings.count -ne 0) {
        $result.Bindings = new-CimBindings $bindings
        $result.Ensure = "Present"
    }

    $result
}

function get-CurrentBindings {
    [CmdletBinding()]
    param($site)

    (Get-TargetResource -Site $site).Bindings
}

function get-HttpBindingInformation {
    [CmdletBinding()]
    param($httpBinding)

    $hostName = $binding.HostName
    $ipAddress = $binding.IPAddress
    $port = $binding.Port

    "${ipAddress}:${port}:${hostName}"
}

function new-BindingsForSite {
    [CmdletBinding()]
    param($ensure, $bindings, $site)

    $currentBindings = @(get-CurrentBindings $site)

    if ($Ensure -eq "Absent") {
        return select-FromBindingsWithoutBindings -From $currentBindings -Without $Bindings
    }

    $newBindings = $currentBindings
    $newBindings += $Bindings
    return $newBindings
}

function new-BindingsWithBindingInformation {
    [CmdletBinding()]
    param($bindings)

    $bindings | ForEach-Object {
        new-CimBinding @{
            BindingInformation = get-BindingInformation $_
            Protocol = $_.Protocol
        }
    }
}

function new-BindingsValue
{
    [CmdletBinding()]
    param($bindings)

    (new-BindingsWithBindingInformation $bindings) | ForEach-Object {
        @{
            bindingInformation = $_.BindingInformation
            protocol = $_.Protocol
        }
    }
}

function new-CimBinding {
    [CmdletBinding()]
    param($binding)

    $bindingProperties = @{
        BindingInformation = $binding.bindingInformation
        Protocol = $binding.protocol
    }

    New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $bindingProperties
}

function new-CimBindings {
    [CmdletBinding()]
    param($bindings)

    $bindings.collection | ForEach-Object { new-CimBinding $_ }
}

function select-CommonBindings {
    [CmdletBinding()]
    param($bindings, $otherBindings)

    $bindings | Where-Object { containsBinding $otherBindings $_ }
}

function select-FromBindingsWithoutBindings {
    [CmdletBinding()]
    param($from, $without)

    $from | Where-Object { -not (containsBinding $without $_) }
}

Export-ModuleMember -Function *-TargetResource
