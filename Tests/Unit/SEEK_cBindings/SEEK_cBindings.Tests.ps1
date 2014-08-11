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

        It "ensure is present" {
            (Get-TargetResource -Site "MySite").Ensure | Should Be "Present"
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

    Context "when a site does not exist" {
        Mock Get-ItemProperty { @() } -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

        It "ensure is absent" {
            (Get-TargetResource -Site "MySite").Ensure | Should Be "Absent"
        }

        It "there are no bindings" {
            (Get-TargetResource -Site "MySite").Bindings.Count | Should Be 0
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

    $missingBindingProperty = @{
                BindingInformation = "Missing Binding Information"
                Protocol = "protocol"
            }
    $missingBinding = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $missingBindingProperty

    $currentBindingProperties = @($firstBindingProperty, $secondBindingProperty)

    Context "when ensure is absent" {

        It "is true, when all bindings are absent" {
            Mock Get-ItemProperty {@{collection = @($firstBindingProperty, $secondBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Ensure "Absent" -Bindings @($missingBinding) -Site "MySite") | Should Be $true
        }

        It "is false, when a binding is present" {
            Mock Get-ItemProperty {@{collection = @($firstBindingProperty, $missingBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Ensure "Absent" -Bindings @($missingBinding) -Site "MySite") | Should Be $false
        }
    }

    Context "when ensure is present" {
        Mock Get-ItemProperty {@{collection = @($firstBindingProperty, $secondBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

        It "is true, when all bindings are present" {
            (Test-TargetResource -Bindings @($firstBinding, $secondBinding) -Site "MySite") | Should Be $true
        }

        It "is true, when unknown bindings are present, but all requested bindings are present" {
            (Test-TargetResource -Bindings @($firstBinding) -Site "MySite") | Should Be $true
        }

        It "is false, when the binding information of one binding is absent" {
            $secondBindingProperty = @{
                BindingInformation = "New Second Binding Information"
                Protocol = "another protocol"
            }
            $secondBinding = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $secondBindingProperty

            Mock Get-ItemProperty {@{collection = $currentBindingProperties}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($firstBinding, $secondBinding) -Site "MySite") | Should Be $false
        }

        It "is false, when the protocol of one binding is absent" {
            $secondBindingProperty = @{
                BindingInformation = "Second Binding Information"
                Protocol = "another new protocol"
            }
            $secondBinding = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $secondBindingProperty

            Mock Get-ItemProperty {@{collection = $currentBindingProperties}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($firstBinding, $secondBinding) -Site "MySite") | Should Be $false
        }

        It "is false, when a binding is missing" {
            Mock Get-ItemProperty {@{collection = $currentBindingProperties}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($firstBinding, $secondBinding, $missingBinding) -Site "MySite") | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {
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

    Mock Get-ItemProperty {@{collection = @($firstBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

    Context "when ensure present" {
        Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
            $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
            $Value.BindingInformation -contains "First Binding Information" -and $Value.Protocol -contains "protocol" -and
            $Value.BindingInformation -contains "Second Binding Information" -and $Value.Protocol -contains "another protocol"
        }

        It "preserves existing bindings while adding new ones" {
            Set-TargetResource -Bindings @($secondBinding) -Site "MySite"
            Assert-VerifiableMocks
        }
    }

    Context "when ensure is absent" {
        Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
            $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
            $Value.BindingInformation -contains "First Binding Information" -and $Value.Protocol -contains "protocol" -and
            $Value.BindingInformation -notcontains "Second Binding Information" -and $Value.Protocol -notcontains "another protocol"
        }

        It "preserves other existing bindings while removing those specified" {
            Set-TargetResource -Ensure "Absent" -Bindings @($secondBinding) -Site "MySite"
            Assert-VerifiableMocks
        }
    }
}