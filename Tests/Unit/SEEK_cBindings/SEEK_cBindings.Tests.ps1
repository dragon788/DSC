$module = Join-Path $PSScriptRoot "..\..\..\Modules\cWebAdministration\DSCResources\SEEK_cBindings\SEEK_cBindings.psm1"
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
    $firstBinding = New-CimBinding -BindingInformation "First Binding Information" -Protocol "protocol"

    $secondBindingProperty = @{
        BindingInformation = "Second Binding Information"
        Protocol = "another protocol"
    }
    $secondBinding = New-CimBinding -BindingInformation "Second Binding Information" -Protocol "another protocol"

    $missingBindingProperty = @{
            BindingInformation = "Missing Binding Information"
            Protocol = "protocol"
        }
    $missingBinding = New-CimBinding -BindingInformation "Missing Binding Information" -Protocol "protocol"

    Context "when ensure is absent" {
        It "is true, when all bindings are absent" {
            Mock Get-ItemProperty {@{collection = @($firstBindingProperty, $secondBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}
            (Test-TargetResource -Ensure "Absent" -Bindings @($missingBinding) -Site "MySite") | Should Be $true
        }

        It "is false, when all provided bindings are absent, but there are existing bindings, and the clear flag is set" {
            Mock Get-ItemProperty {@{collection = @($firstBindingProperty, $secondBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}
            (Test-TargetResource -Ensure "Absent" -Bindings @($missingBinding) -Clear $true -Site "MySite") | Should Be $false
        }

        It "is false, when a binding that should be absent is present" {
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

        It "is false, when unknown bindings are present, all requested bindings are present, and the clear flag is set" {
            (Test-TargetResource -Bindings @($firstBinding) -Clear $true -Site "MySite") | Should Be $false
        }

        It "is false, when the binding information of one binding is absent" {
            $missingBindingInformationProperty = @{
                BindingInformation = "New Second Binding Information"
                Protocol = "another protocol"
            }
            $missingBindingInformation = New-CimBinding -BindingInformation "New Second Binding Information" -Protocol "another protocol"

            Mock Get-ItemProperty {@{collection =  @($firstBindingProperty, $secondBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($firstBinding, $missingBindingInformation) -Site "MySite") | Should Be $false
        }

        It "is false, when the protocol of one binding is absent" {
            $missingProtocolProperty = @{
                BindingInformation = "Second Binding Information"
                Protocol = "another new protocol"
            }
            $missingProtocol = New-CimInstance -ClassName SEEK_cBinding -ClientOnly -Property $missingProtocolProperty

            Mock Get-ItemProperty {@{collection =  @($firstBindingProperty, $secondBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($firstBinding, $missingProtocol) -Site "MySite") | Should Be $false
        }

        It "is false, when a binding is missing" {
            Mock Get-ItemProperty {@{collection =  @($firstBindingProperty, $secondBindingProperty)}} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($firstBinding, $secondBinding, $missingBinding) -Site "MySite") | Should Be $false
        }

    }

    Context "when given a http binding" {
        $httpCimBinding = New-HttpCimBinding -HostName "the-host" -IPAddress "127.0.0.1" -Port 80
        $httpBindingHash = @{ BindingInformation = "127.0.0.1:80:the-host"; Protocol = "http" }

        It "is true, when ensure is present, and the binding is present" {
            Mock Get-ItemProperty {@{collection = @($httpBindingHash)}} -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($httpCimBinding) -Site "MySite") | Should be $true
            Assert-VerifiableMocks
        }

        It "is true, when ensure is absent, and the binding is absent" {
            Mock Get-ItemProperty {@{collection = @($firstBindingProperty)}} -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Ensure "Absent" -Bindings @($httpCimBinding) -Site "MySite") | Should be $true
            Assert-VerifiableMocks
        }

        It "is false, when ensure is present, and the binding is absent" {
            Mock Get-ItemProperty {@{collection = @($firstBindingProperty)}} -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($httpCimBinding) -Site "MySite") | Should be $false
            Assert-VerifiableMocks
        }

        It "is false, when ensure is absent, and the binding is present" {
            Mock Get-ItemProperty {@{collection = @($httpBindingHash)}} -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Ensure "Absent" -Bindings @($httpCimBinding) -Site "MySite") | Should be $false
            Assert-VerifiableMocks
        }
    }

    Context "when given a https binding" {
        Mock Get-ChildItem {@(@{Subject = "certificate subject"; Thumbprint = "thumbprint"})}

        $httpsCimBinding = New-HttpsCimBinding -CertificatePath "Cert:\ssl-cert-path" -CertificateSubject "certificate subject" -IPAddress "*" -Port 443
        $httpsBindingHash = @{ BindingInformation = "*:443:"; Protocol = "https"; certificatePath = "Cert:\ssl-cert-path"; CertificateSubject = "certificate subject" }

        It "is true, when ensure is present, the binding is present, and the certificates match" {
            Mock Get-ItemProperty { @{collection = @($httpsBindingHash)} } -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($httpsCimBinding) -Site "MySite") | Should Be $true
            Assert-VerifiableMocks
        }

        It "is true, when ensure is absent and the binding is absent" {
            Mock Get-ItemProperty {@{collection = @($firstBindingProperty)}} -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Ensure "Absent" -Bindings @($httpsCimBinding) -Site "MySite") | Should Be $true
            Assert-VerifiableMocks
        }

        It "is false, when ensure is present, the binding is present, and certificates do not match" {
            $httpsBindingHashBadThumbprint = @{ BindingInformation = "127.0.0.1:443:"; Protocol = "https"; certificateHash = "toeprint"; CertificateStoreName = "certificate store name" }
            Mock Get-ItemProperty {@{collection = @($httpsBindingHashBadThumbprint)}} -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($httpsCimBinding) -Site "MySite") | Should Be $false
            Assert-VerifiableMocks
        }

        It "is false, when ensure is present and the binding is absent" {
            Mock Get-ItemProperty {@{collection = @($firstBindingProperty)}} -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}

            (Test-TargetResource -Bindings @($httpsCimBinding) -Site "MySite") | Should Be $false
            Assert-VerifiableMocks
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
    Mock Set-ItemProperty {} -ParameterFilter { <#$Path -eq "IIS:\Sites\MySite" -and#> $Name -eq "EnabledProtocols"}

    Context "when ensure present" {
        It "preserves existing bindings by default" {
            Mock Set-ItemProperty {}<# -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
                $Value.BindingInformation -contains "First Binding Information" -and $Value.Protocol -contains "protocol"
            }#>

            Set-TargetResource -Bindings @($secondBinding) -Site "MySite"
            #Assert-VerifiableMocks
        }

        It "adds new bindings" {
          Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
              $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
              $Value.BindingInformation -contains "Second Binding Information" -and $Value.Protocol -contains "another protocol"
          }

          Set-TargetResource -Bindings @($secondBinding) -Site "MySite"
          Assert-VerifiableMocks
        }

        It "enables protocols for the site" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite" -and $Name -eq "EnabledProtocols" -and
                $Value -eq "protocol,another protocol"
            }

            Set-TargetResource -Bindings @($secondBinding) -Site "MySite"
            Assert-VerifiableMocks
        }

       It "clobbers existing bindings when clear flag is set" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
                $Value.BindingInformation -notcontains "First Binding Information" -and $Value.Protocol -notcontains "protocol"
            }

            Set-TargetResource -Bindings @($secondBinding) -Clear $true -Site "MySite"
            Assert-VerifiableMocks
        }
    }

    Context "when ensure is absent" {
        It "preserves existing bindings while removing those specified by default" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
                    $Value.BindingInformation -contains "First Binding Information" -and $Value.Protocol -contains "protocol" -and
                    $Value.BindingInformation -notcontains "Second Binding Information" -and $Value.Protocol -notcontains "another protocol"
            }

            Set-TargetResource -Ensure "Absent" -Bindings @($secondBinding) -Site "MySite"
            Assert-VerifiableMocks
        }

        It "removes all bindings when clear flag is set" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
                    $Value.BindingInformation -notcontains "First Binding Information" -and $Value.Protocol -notcontains "protocol" -and
                    $Value.BindingInformation -notcontains "Second Binding Information" -and $Value.Protocol -notcontains "another protocol"
            }

            Set-TargetResource -Ensure "Absent" -Bindings @($secondBinding) -Clear $true -Site "MySite"
            Assert-VerifiableMocks
        }

    }

    Context "when given a http binding" {
        $httpCimBinding = New-HttpCimBinding -HostName "the-host" -IPAddress "127.0.0.1" -Port 80
        $httpBindingHash = @{ BindingInformation = "127.0.0.1:80:the-host"; Protocol = "http" }

        It "adds the binding while preserving existing bindings, when ensure is present" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
                $Value.BindingInformation -contains "First Binding Information" -and $Value.Protocol -contains "protocol" -and
                $Value.BindingInformation -contains "127.0.0.1:80:the-host" -and $Value.Protocol -contains "http"
            }

            Set-TargetResource -Bindings @($httpCimBinding) -Site "MySite"
            Assert-VerifiableMocks
        }

        It "removes the binding while preserving existing bindings, when ensure is absent" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
                $Value.BindingInformation -contains "First Binding Information" -and $Value.Protocol -contains "protocol" -and
                $Value.BindingInformation -notcontains "127.0.0.1:80:the-host" -and $Value.Protocol -notcontains "http"
            }

            Set-TargetResource -Ensure "Absent" -Bindings @($httpCimBinding) -Site "MySite"
            Assert-VerifiableMocks
        }
    }

    Context "when given a https binding" {
        Mock Get-ChildItem {@(@{Subject = "certificate subject"; Thumbprint = "thumbprint"})}

        $httpsCimBinding = New-HttpsCimBinding -CertificatePath "Cert:\ssl-cert-path" -CertificateSubject "certificate subject" -IPAddress "*" -Port 443
        $httpsBindingHash = @{ BindingInformation = "*:443:"; Protocol = "https"; certificatePath = "Cert:\ssl-cert-path"; CertificateSubject = "certificate subject" }

        It "removes the binding, preserving existing bindings, when ensure is absent" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
                $Value.BindingInformation -contains "First Binding Information" -and $Value.Protocol -contains "protocol" -and
                $Value.BindingInformation -notcontains "*:443:" -and $Value.Protocol -notcontains "https"
            }

            Set-TargetResource -Ensure "Absent" -Bindings @($httpsCimBinding) -Site "MySite"
            Assert-VerifiableMocks
        }

        It "adds the binding, preserving existing bindings, and assigns the certificate, when ensure is present" {
            Mock Get-Item { @{} } -Verifiable -ParameterFilter { $Path -eq "Cert:\ssl-cert-path\thumbprint" }
            Mock New-Item {} -Verifiable -ParameterFilter { $Path -eq "IIS:\SslBindings\0.0.0.0!443" }

            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and
                $Value.BindingInformation -contains "First Binding Information" -and $Value.Protocol -contains "protocol" -and
                $Value.BindingInformation -contains "*:443:" -and $Value.Protocol -contains "https"
            }

            Set-TargetResource -Bindings @($httpsCimBinding) -Site "MySite"
            Assert-VerifiableMocks
        }
    }
}


