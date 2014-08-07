$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cWebAdministration\DSCResources\SEEK_cBindings\SEEK_cBindings.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Get-TargetResource" {
    $bindingProperties = @{
        BindingInformation = "Binding Information"
        Protocol = "protocol"
    }

    Context "when site has a single binding" {
        Mock Get-ItemProperty {@{collection = $bindingProperties}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

        It "has the binding information" {
            (Get-TargetResource -Site "MySite").Bindings.BindingInformation | Should Be "Binding Information"
        }

        It "has the protocol" {
            (Get-TargetResource -Site "MySite").Bindings.Protocol | Should Be "protocol"
        }
    }

    Context "when a site has multiple bindings" {
        $additionalBindingProperties = @{
            BindingInformation = "Additional Binding Information"
            Protocol = "protocol"
        }

        Mock Get-ItemProperty {@{collection = @($bindingProperties, $additionalBindingProperties)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

        It "has all the bindings" {
            (Get-TargetResource -Site "MySite").Bindings.BindingInformation.Length | Should Be 2
        }
    }
}

Describe "Test-TargetResource" {
    $firstBindingProperty = @{
        BindingInformation = "First Binding Information"
        Protocol = "protocol"
    }
    $firstBinding = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $firstBindingProperty

    $secondBindingProperty = @{
        BindingInformation = "Second Binding Information"
        Protocol = "another protocol"
    }
    $secondBinding = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $secondBindingProperty

    $currentBindingProperties = @($firstBindingProperty, $secondBindingProperty)

    Context "when all the bindings match" {
        Mock Get-ItemProperty {@{collection = $currentBindingProperties}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

        It "is true" {
            (Test-TargetResource -Bindings @($firstBinding, $secondBinding) -Site "MySite") | Should Be $true
        }
    }

    Context "when the binding information of one binding does not match" {
        $secondBindingProperty = @{
            BindingInformation = "New Second Binding Information"
            Protocol = "another protocol"
        }
        $secondBinding = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $secondBindingProperty

        Mock Get-ItemProperty {@{collection = $currentBindingProperties}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

        It "is false" {
            (Test-TargetResource -Bindings @($firstBinding, $secondBinding) -Site "MySite") | Should Be $false
        }
    }

    Context "when the protocol of one binding does not match" {
        $secondBindingProperty = @{
            BindingInformation = "Second Binding Information"
            Protocol = "another new protocol"
        }
        $secondBinding = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $secondBindingProperty

        Mock Get-ItemProperty {@{collection = $currentBindingProperties}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

        It "is false" {
            (Test-TargetResource -Bindings @($firstBinding, $secondBinding) -Site "MySite") | Should Be $false
        }
    }

    Context "when a binding is missing" {
        $missingBindingProperty = @{
            BindingInformation = "Missing Binding Information"
            Protocol = "protocol"
        }
        $missingBinding = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $missingBindingProperty

        Mock Get-ItemProperty {@{collection = $currentBindingProperties}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

        It "is false" {
            (Test-TargetResource -Bindings @($firstBinding, $secondBinding, $missingBinding) -Site "MySite") | Should Be $false
        }
    }

    Context "when there is an unknown binding" {
        $unknownBindingProperty = @{
            BindingInformation = "Unknown Binding Information"
            Protocol = "protocol"
        }

        It "is true, given all requested bindings are present" {
             Mock Get-ItemProperty {@{collection = @($firstBindingProperty, $secondBindingProperty, $unknownBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}
            (Test-TargetResource -Bindings @($firstBinding, $secondBinding) -Site "MySite") | Should Be $true
        }

        It "is false, unless all requested bindings are present" {
             Mock Get-ItemProperty {@{collection = @($firstBindingProperty, $unknownBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}
            (Test-TargetResource -Bindings @($firstBinding, $secondBinding) -Site "MySite") | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {

    $firstBindingProperty = @{
        BindingInformation = "First Binding Information"
        Protocol = "protocol"
    }
    $firstBinding = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $firstBindingProperty

    Mock Set-ItemProperty {} -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and $Value.BindingInformation -eq "First Binding Information" -and $Value.Protocol -eq "protocol"}

    It "sets the bindings property" {
        Set-TargetResource -Bindings $firstBinding -Site "MySite"
        Assert-VerifiableMocks
    }

}