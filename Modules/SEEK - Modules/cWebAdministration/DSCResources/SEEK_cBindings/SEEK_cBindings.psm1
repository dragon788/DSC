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

    $transformedBindings = $bindings.collection | ForEach-Object {
        $bindingProperties = @{
            BindingInformation = $_.bindingInformation
            Protocol = $_.protocol
        }

        New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $bindingProperties
    }

    return @{
        Bindings = $transformedBindings
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

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Bindings = @()
    )

    $currentBindings = Get-TargetResource -Site $Site

    $unfoundBinding = $false
    $Bindings | ForEach-Object {
        $foundBinding = $false
        $bindingToFind = $_
        $currentBindings.Bindings | ForEach-Object {
            if(-not $foundBinding) {
                $foundBinding = equalBindings $bindingToFind $_
            }
        }

        if(-not $foundBinding) {
            $unfoundBinding = $true
        }
    }

    return -not $unfoundBinding
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String] $Site,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Bindings = @()
    )

    $newBindings = $Bindings
    $newBindings += (Get-TargetResource -Site $Site).Bindings

    Set-ItemProperty -Path "IIS:\Sites\${Site}" -Name bindings -Value $newBindings
}

function equalBindings {
    [CmdletBinding()]
    param($bindingOne, $bindingTwo)

    $matchingBindingInformation = $bindingOne.BindingInformation -eq $bindingTwo.BindingInformation
    $matchingProtocol = $bindingOne.Protocol -eq $bindingTwo.Protocol
    return $matchingBindingInformation -and $matchingProtocol
}

Export-ModuleMember -Function *-TargetResource
