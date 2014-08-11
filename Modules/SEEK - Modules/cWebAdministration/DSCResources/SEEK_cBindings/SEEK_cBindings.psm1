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

    $bindings = Get-ItemProperty "IIS:\Sites\${Site}" -Name bindings

    if($bindings.count -eq 0) {
        return @{
            Bindings = @()
            Ensure = "Absent"
            Site = $Site
        }
    }

    return @{
        Bindings = cimifyBindings $bindings
        Ensure = "Present"
        Site = $Site
    }
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

    $currentBindings = @((Get-TargetResource -Site $Site).Bindings)

    $presentBindings = commonBindings $Bindings $currentBindings

    if ($Ensure -eq "Absent") {
        return $presentBindings.count -eq 0
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

    $currentBindings = @((Get-TargetResource -Site $Site).Bindings)

    if ($Ensure -eq "Absent") {
        $newBindings = removeBindings $currentBindings $Bindings
    }
    else {
        $newBindings = $currentBindings
        $newBindings += $Bindings
    }

    $bindingsValue = $newBindings | ForEach-Object {@{
        bindingInformation = $_.BindingInformation
        protocol = $_.Protocol
    }}

    Set-ItemProperty -Path "IIS:\Sites\${Site}" -Name bindings -Value $bindingsValue
}

function cimifyBindings {
    [CmdletBinding()]
    param($bindings)

    return $bindings.collection | ForEach-Object {
        $bindingProperties = @{
            BindingInformation = $_.bindingInformation
            Protocol = $_.protocol
        }

        New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $bindingProperties
    }
}

function commonBindings {
    [CmdletBinding()]
    param($bindings, $otherBindings)

    $bindings | Where-Object { containsBinding $otherBindings $_ }
}

function containsBinding {
    [CmdletBinding()]
    param($bindings, $binding)

    $bindings | ForEach-Object {
        if(equalBindings $_ $binding) { return $true }
    }

    return $false
}

function equalBindings {
    [CmdletBinding()]
    param($bindingOne, $bindingTwo)

    $matchingBindingInformation = $bindingOne.BindingInformation -eq $bindingTwo.BindingInformation
    $matchingProtocol = $bindingOne.Protocol -eq $bindingTwo.Protocol
    return $matchingBindingInformation -and $matchingProtocol
}

function removeBindings {
    [CmdletBinding()]
    param($bindings, $bindingsToRemove)

    $bindings | Where-Object { -not (containsBinding $bindingsToRemove $_) }
}

Export-ModuleMember -Function *-TargetResource
