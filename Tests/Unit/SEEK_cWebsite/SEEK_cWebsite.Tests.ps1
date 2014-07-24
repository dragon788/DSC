$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cWebAdministration\DSCResources\SEEK_cWebsite\SEEK_cWebsite.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Mock Get-Website {$null}
Mock Get-ItemProperty {return $null}
Mock Get-WebConfigurationProperty {return $null}

$MockWebsite = New-Object PSObject -Property @{
    state = "Started"
    applicationPool = "MyAppPool"
    id = 9999
    name = "MySite"
    physicalPath = "C:\inetpub\wwwroot\mysite"
    count = 1 # behaving like a ConfigurationElement object with a single element
}

$MockHttpBinding = New-Object PSObject -Property @{
    bindingInformation = "192.168.0.1:80:www.mysite.com"
    protocol = "http"
}

$MockNetPipeBinding = New-Object PSObject -Property @{
    bindingInformation = "my.service"
    protocol = "net.pipe"
}

$MockNetTcpBinding = New-Object PSObject -Property @{
    bindingInformation = "5555:my.service"
    protocol = "net.tcp"
}

$MockHttpsBinding = New-Object PSObject -Property @{
    bindingInformation = "192.168.200.1:443:www.mysite.com"
    protocol = "https"
    certificateHash = "6CAE3EB1EAE470FA836B350E227B3AE2E9B6F93E"
    certificateStoreName = "Cert://localmachine/my"
}

Describe "Get-TargetResource" {
    Context "when the web site is present" {
        Mock Get-Website {$MockWebsite}
        Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
            -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("AnonymousAuthentication")}
        Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
            -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("BasicAuthentication")}
        Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
            -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("DigestAuthentication")}
        Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
            -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("WindowsAuthentication")}
        Mock Get-ItemProperty {New-Object PSObject -Property @{Collection = @($MockHttpsBinding)}} `
            -ParameterFilter {$Name -eq "Bindings"}

        It "returns the web site state as a hashtable" {
            $WebSite = Get-TargetResource -Name "MySite"
            $WebSite.Name | Should Be "MySite"
            $WebSite.Ensure | Should Be "Present"
            $WebSite.PhysicalPath | Should Be "C:\inetpub\wwwroot\mysite"
            $WebSite.State | Should Be "Started"
            $WebSite.ID | Should Be "9999"
            $WebSite.ApplicationPool | Should Be "MyAppPool"
            $WebSite.BindingInfo.Port | Should Be "443"
            $WebSite.BindingInfo.Protocol | Should Be "https"
            $WebSite.BindingInfo.IPAddress | Should Be "192.168.200.1"
            $WebSite.BindingInfo.HostName | Should Be "www.mysite.com"
            $WebSite.BindingInfo.CertificateThumbprint | Should Be "6CAE3EB1EAE470FA836B350E227B3AE2E9B6F93E"
            $WebSite.BindingInfo.CertificateStoreName | Should Be "Cert://localmachine/my"
            $WebSite.AuthenticationInfo.Anonymous | Should Be "true"
            $WebSite.AuthenticationInfo.Basic | Should Be "false"
            $WebSite.AuthenticationInfo.Digest | Should Be "false"
            $WebSite.AuthenticationInfo.Windows | Should Be "true"
            $WebSite.HostFileInfo | Should Be $null
        }
    }

    Context "when the web site is absent" {
        It "returns an absent web site hashtable" {
            $WebSite = Get-TargetResource -Name "MySite"
            $WebSite.Name | Should Be "MySite"
            $WebSite.Ensure | Should Be "Absent"
            $WebSite.PhysicalPath | Should Be $null
            $WebSite.State | Should Be $null
            $WebSite.ID | Should Be $null
            $WebSite.ApplicationPool | Should Be $null
            $WebSite.BindingInfo | Should Be $null
            $WebSite.AuthenticationInfo | Should Be $null
            $WebSite.HostFileInfo | Should Be $null
        }
    }

    Context "when the multiple websites with the same name are present" {
        Mock Get-Website { @($MockWebsite, $MockWebsite) }

        It "throws an exception" {
            $exception = $null
            try { Get-TargetResource -Name "MySite" }
            catch { $exception = $_ }
            $exception | Should Not Be $null
        }
    }
}

Describe "Test-TargetResource" {
    Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
        -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("AnonymousAuthentication")}
    Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
        -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("BasicAuthentication")}
    Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
        -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("DigestAuthentication")}
    Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
        -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("WindowsAuthentication")}
    Mock Get-ItemProperty {"C:\foo"} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "physicalPath"}

    $HttpBindingInfo = New-CimInstance -ClassName SEEK_cWebBindingInformation `
        -Namespace root/microsoft/Windows/DesiredStateConfiguration `
        -ClientOnly `
        -Property @{Port=[System.UInt16]80;Protocol="http";IPAddress="192.168.0.1";HostName="www.mysite.com"}
    $NetPipeBindingInfo = New-CimInstance -ClassName SEEK_cWebBindingInformation `
        -Namespace root/microsoft/Windows/DesiredStateConfiguration `
        -ClientOnly `
        -Property @{Protocol="net.pipe";HostName="my.service"}
    $NetTcpBindingInfo = New-CimInstance -ClassName SEEK_cWebBindingInformation `
        -Namespace root/microsoft/Windows/DesiredStateConfiguration `
        -ClientOnly `
        -Property @{Port=[System.UInt16]5555;Protocol="net.tcp";HostName="my.service"}
    $AuthenticationInfo = New-CimInstance -ClassName SEEK_cWebAuthenticationInformation -ClientOnly `
        -Property @{Anonymous = $true; Basic = $false; Digest = $false; Windows = $true}
    $BindingInfo = @($NetPipeBindingInfo, $NetTcpBindingInfo, $HttpBindingInfo)
    Mock Get-ItemProperty {New-Object PSObject -Property @{Collection = @($MockNetPipeBinding, $MockNetTcpBinding, $MockHttpBinding)}} `
                -ParameterFilter {$Name -eq "Bindings"}

    Context "when the web site is in the desired state" {
        Mock Get-Website {New-Object PSObject -Property @{name = "MySite"; state = "Started"; physicalPath = "C:\foo"; applicationPool = "MyAppPool"; count = 1}}
        It "returns true" {
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo | Should Be $true
        }
    }

    Context "when the web site differs from the desired state" {
        Mock Get-Website {New-Object PSObject -Property @{name = "MySite"; state = "Started"; physicalPath = "C:\foo"; applicationPool = "MyAppPool"; count = 1}}
        It "returns false if the physical path is different" {
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\bar" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo | Should Be $false
        }

        It "returns false if the state is different" {
            Test-TargetResource -Name "MySite" -State "Stopped" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo | Should Be $false
        }

        It "returns false if the application pool is different" {
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "OtherAppPool" -AuthenticationInfo $AuthenticationInfo | Should Be $false
        }

        It "returns true if the existing site has more bindings" {
            Mock Get-ItemProperty {New-Object PSObject -Property @{Collection = @($MockNetPipeBinding, $MockHttpBinding)}} `
                -ParameterFilter {$Name -eq "Bindings"}
            $BindingInfo = @($HttpBindingInfo)
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo | Should Be $true
        }

        It "returns false if the existing site has less bindings" {
            Mock Get-ItemProperty {New-Object PSObject -Property @{Collection = @($MockHttpBinding)}} `
                -ParameterFilter {$Name -eq "Bindings"}
            $BindingInfo = @($NetTcpBindingInfo, $HttpBindingInfo)
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo | Should Be $false
        }

        It "returns false if the binding values are different" {
            $DifferentHttpBindingInfo = New-CimInstance -ClassName SEEK_cWebBindingInformation `
                -Namespace root/microsoft/Windows/DesiredStateConfiguration `
                -ClientOnly `
                -Property @{Port=[System.UInt16]80;Protocol="http";IPAddress="192.168.0.1";HostName="www.othersite.com"}
            $BindingInfo = @($NetPipeBindingInfo, $NetTcpBindingInfo, $DifferentHttpBindingInfo)
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo | Should Be $false
        }
    }

    Context "when web site is absent" {
        Mock Get-Website {$null}
        It "returns false" {
            Test-TargetResource -Name "MySite" -Ensure "Present" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {
    Mock New-Website {$MockWebsite}
    Mock Stop-Website
    Mock Start-Website
    Mock Remove-Website
    Mock Clear-ItemProperty {}
    Mock New-ItemProperty {}
    Mock Set-WebConfigurationProperty {}
    Mock Set-WebConfiguration {}
    Mock Set-ItemProperty {}

    $HttpBindingInfo = New-CimInstance -ClassName SEEK_cWebBindingInformation `
        -Namespace root/microsoft/Windows/DesiredStateConfiguration `
        -ClientOnly `
        -Property @{Port=[System.UInt16]80;Protocol="http";IPAddress="192.168.0.1";HostName="www.mysite.com"}
    $NetPipeBindingInfo = New-CimInstance -ClassName SEEK_cWebBindingInformation `
        -Namespace root/microsoft/Windows/DesiredStateConfiguration `
        -ClientOnly `
        -Property @{Protocol="net.pipe";HostName="my.service"}
    $NetTcpBindingInfo = New-CimInstance -ClassName SEEK_cWebBindingInformation `
        -Namespace root/microsoft/Windows/DesiredStateConfiguration `
        -ClientOnly `
        -Property @{Port=[System.UInt16]5555;Protocol="net.tcp";HostName="my.service"}
    $AuthenticationInfo = New-CimInstance -ClassName SEEK_cWebAuthenticationInformation -ClientOnly `
        -Property @{Anonymous = $true; Basic = $false; Digest = $false; Windows = $true}
    $BindingInfo = @($NetPipeBindingInfo, $NetTcpBindingInfo, $HttpBindingInfo)

    Context "when no web sites exist" {
        Mock Get-Website {$null}

        It "creates a new web site with an ID of 1" {
            Mock New-Website -Verifiable -ParameterFilter {$Id -eq 1}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }
    }

    Context "when web site is absent" {

        Mock Get-Website {New-Object PSObject -Property @{name = "OtherSite"}}

        It "creates a new web site" {
            Mock New-Website -Verifiable -ParameterFilter {$Name -eq "MySite" -and $PhysicalPath -eq "C:\foo" -and $ApplicationPool -eq "MyAppPool"}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }

        It "creates new bindings" {
            Mock New-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and $Value.Protocol -eq "http" -and $Value.BindingInformation -eq "192.168.0.1:80:www.mysite.com"}
            Mock New-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and $Value.Protocol -eq "net.pipe" -and $Value.BindingInformation -eq "my.service"}
            Mock New-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and $Value.Protocol -eq "net.tcp" -and $Value.BindingInformation -eq "5555:my.service"}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }

        It "sets the protocols enabled" {
            Mock Set-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "EnabledProtocols" -and $Value -eq "net.pipe,net.tcp,http"}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }

        It "creates new authentication info" {
            Mock Set-WebConfigurationProperty -Verifiable `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("AnonymousAuthentication") -and $Name -eq "enabled" -and $Value -eq $true -and $Location -eq "MySite"}
            Mock Set-WebConfigurationProperty -Verifiable `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("BasicAuthentication") -and $Name -eq "enabled" -and $Value -eq $false -and $Location -eq "MySite"}
            Mock Set-WebConfigurationProperty -Verifiable `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("DigestAuthentication") -and $Name -eq "enabled" -and $Value -eq $false -and $Location -eq "MySite"}
            Mock Set-WebConfigurationProperty -Verifiable `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("WindowsAuthentication") -and $Name -eq "enabled" -and $Value -eq $true -and $Location -eq "MySite"}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }
    }

    Context "when web site is present" {
        Mock Get-Website {$MockWebsite}
        Mock Get-WebConfigurationProperty {$null}
        Mock Get-ItemProperty {$null}

        It "does not create a new web site" {
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-MockCalled New-Website -Times 0
        }

        It "updates the existing web site" {
            Mock Set-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "physicalPath" -and $Value -eq "C:\bar"}
            Mock Set-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "applicationPool" -and $Value -eq "NewAppPool"}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\bar" -ApplicationPool "NewAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }

        It "replaces the bindings" {
            Mock Get-ItemProperty {New-Object PSObject -Property @{Collection = @($MockHttpBinding)}} `
                -ParameterFilter {$Name -eq "Bindings"}
            Mock Clear-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings"}
            Mock New-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and $Value.Protocol -eq "http" -and $Value.BindingInformation -eq "192.168.0.1:80:www.mysite.com"}
            Mock New-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and $Value.Protocol -eq "net.pipe" -and $Value.BindingInformation -eq "my.service"}
            Mock New-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "bindings" -and $Value.Protocol -eq "net.tcp" -and $Value.BindingInformation -eq "5555:my.service"}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }

        It "updates the protocols enabled" {
            Mock Get-ItemProperty {New-Object PSObject -Property @{Collection = @($MockHttpBinding)}} `
                -ParameterFilter {$Name -eq "Bindings"}
            Mock Set-ItemProperty -Verifiable -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "EnabledProtocols" -and $Value -eq "net.pipe,net.tcp,http"}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }

        It "updates the authentication info" {
            Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("AnonymousAuthentication")}
            Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("BasicAuthentication")}
            Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("DigestAuthentication")}
            Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("WindowsAuthentication")}
            Mock Set-WebConfigurationProperty -Verifiable `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("AnonymousAuthentication") -and $Name -eq "enabled" -and $Value -eq $false -and $Location -eq "MySite"}
            Mock Set-WebConfigurationProperty -Verifiable `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("BasicAuthentication") -and $Name -eq "enabled" -and $Value -eq $true -and $Location -eq "MySite"}
            Mock Set-WebConfigurationProperty -Verifiable `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("DigestAuthentication") -and $Name -eq "enabled" -and $Value -eq $true -and $Location -eq "MySite"}
            Mock Set-WebConfigurationProperty -Verifiable `
                -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("WindowsAuthentication") -and $Name -eq "enabled" -and $Value -eq $true -and $Location -eq "MySite"}
            $AuthenticationInfo = New-CimInstance -ClassName SEEK_cWebAuthenticationInformation -ClientOnly `
                -Property @{Anonymous = $false; Basic = $true; Digest = $true; Windows = $true}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo
            Assert-VerifiableMocks
        }
    }

    Context "when desired state is equal to the web site state" {
        Mock Get-Website {$MockWebsite}
        Mock Set-ItemProperty {}
        Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
            -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("AnonymousAuthentication")}
        Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
            -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("BasicAuthentication")}
        Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
            -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("DigestAuthentication")}
        Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
            -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("WindowsAuthentication")}
        Mock Get-ItemProperty {New-Object PSObject -Property @{Collection = @($MockNetPipeBinding, $MockNetTcpBinding, $MockHttpBinding)}} `
                -ParameterFilter {$Name -eq "Bindings"}
        Mock Get-ItemProperty {"C:\foo"} -ParameterFilter {$Name -eq "physicalPath"}

        It "does nothing" {
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo
            Assert-MockCalled New-Website -Times 0
            Assert-MockCalled Set-ItemProperty -Times 0
            Assert-MockCalled Set-WebConfigurationProperty -Times 0
            Assert-MockCalled Stop-Website -Times 0
            Assert-MockCalled Start-Website -Times 0
        }
    }

    Context "when desired state is stopped and web site is started" {
        Mock Get-Website {New-Object PSObject -Property @{state = "Started"; applicationPool = "MyAppPool"; name = "MySite"; physicalPath = "C:\inetpub\wwwroot\mysite"; count = 1}}

        It "stops the web site" {
            Mock Stop-Website -Verifiable -ParameterFilter {$Name -eq "MySite"}
            Set-TargetResource -Name "MySite" -State "Stopped" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-MockCalled Start-Website -Times 0
            Assert-VerifiableMocks
        }
    }

    Context "when desired state is started and web site is stopped" {
        Mock Get-Website {New-Object PSObject -Property @{state = "Stopped"; applicationPool = "MyAppPool"; name = "MySite"; physicalPath = "C:\inetpub\wwwroot\mysite"; count = 1}}

        It "starts the web site" {
            Mock Start-Website -Verifiable -ParameterFilter {$Name -eq "MySite"}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }
    }

    Context "when configuration specifies the web site should be absent" {
        Mock Get-Website {$MockWebsite}

        It "removes the web site" {
            Mock Remove-website -Verifiable -ParameterFilter {$Name -eq "MySite"}
            Set-TargetResource -Name "MySite" -Ensure "Absent" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }
    }

    Context "when bindings are not unique" {
        It "terminates the creation of the web site" {
            Mock ThrowTerminatingError {} -Verifiable
            $httpBinding = New-CimInstance -ClassName SEEK_cWebBindingInformation -Namespace root/microsoft/Windows/DesiredStateConfiguration -Property @{Port=[System.UInt16]80;Protocol="http";IPAddress="192.168.0.1";HostName="www.mysite.com"} -ClientOnly
            $BindingInfo = @($httpBinding, $httpBinding)
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo
            Assert-VerifiableMocks
        }
    }

    Context "when https binding is specified" {
        $httpsBindingProperties = @{
            Port=[System.UInt16]443
            Protocol="https"
            IPAddress="192.168.200.1"
            HostName="www.mysite.com"
            CertificateStoreName="My"
            SslCertPath="Cert://localmachine/my"
            SslSubject="CN=www.mysite.com"
        }
        $mockCertificate = New-Object PSObject -Property @{
            Subject = "CN=www.mysite.com"
            Thumbprint = "6CAE3EB1EAE470FA836B350E227B3AE2E9B6F93E"
        }
        $mockHttpsBinding = New-Object PSObject -Property @{
            bindingInformation = "192.168.200.1:443:www.mysite.com"
            protocol = "https"
            certificateHash = "OLDTHUMBPRINT"
            certificateStoreName = "Cert://localmachine/my"
        }
        Mock Get-ChildItem {$mockCertificate} -ParameterFilter {$Path -eq "Cert://localmachine/my"}
        Mock Get-WebBinding {$mockHttpsBinding} -ParameterFilter {$Name -eq "MySite" -and $Port -eq 443}
        Mock Set-BindingCertificate {}

        It "replaces the ssl certificate on the web site binding" {
            $bindingInfo = @(New-CimInstance -ClassName SEEK_cWebBindingInformation `
                -Namespace root/microsoft/Windows/DesiredStateConfiguration `
                -ClientOnly `
                -Property $httpsBindingProperties
            )
            Mock Set-BindingCertificate {} -Verifiable -ParameterFilter {($Binding.bindingInformation) -eq "192.168.200.1:443:www.mysite.com" -and $CertificateThumbprint -eq "6CAE3EB1EAE470FA836B350E227B3AE2E9B6F93E" -and $CertificateStoreName -eq "My"}
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $bindingInfo
            Assert-VerifiableMocks
        }
    }

    Context "when hosts are specified" {
        $hostsFilePath = "TestDrive:\hosts"
        Mock Get-HostsFilePath {$hostsFilePath}
        $hostFileInfo = @(New-CimInstance -ClassName SEEK_cHostEntryFileInformation -Namespace root/microsoft/Windows/DesiredStateConfiguration -Property @{ RequireHostFileEntry = "true"; HostEntryName = "www.mysite.com"; HostIpAddress = "192.168.200.1" } -ClientOnly)

        It "leaves the hosts file unchanged if a hosts file entry already exists with the same IP address" {
            Set-Content $hostsFilePath -value "192.168.200.1    www.mysite.com"
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo -HostFileInfo $hostFileInfo
            (Get-Content $hostsFilePath) -join "`n" | Should Be "192.168.200.1    www.mysite.com"
        }

        It "updates the hosts file entry with the new IP address if a hosts file entry already exists for a different IP address"{
            Set-Content $hostsFilePath -value "192.168.200.3    www.mysite.com"
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo -HostFileInfo $hostFileInfo
            (Get-Content $hostsFilePath) -join "`n" | Should Be "192.168.200.1    www.mysite.com"
        }

        It "adds a new entry to the hosts file if a hosts file entry does not exist" {
            Set-Content $hostsFilePath -value "192.168.200.3    www.othersite.com"
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo -HostFileInfo $hostFileInfo
            (Get-Content $hostsFilePath) -join "`n" | Should Be "192.168.200.3    www.othersite.com`n`n192.168.200.1    www.mysite.com"
        }

        It "adds a new entry to the hosts file if the hosts file is empty" {
            Set-Content $hostsFilePath -value ""
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo -HostFileInfo $hostFileInfo
            (Get-Content $hostsFilePath) -join "`n" | Should Be "`n`n192.168.200.1    www.mysite.com"
        }
    }

    Context "when hosts are specified but not required" {
        $hostsFilePath = "TestDrive:\hosts"
        Mock Get-HostsFilePath {$hostsFilePath}
        $hostFileInfo = @(New-CimInstance -ClassName SEEK_cHostEntryFileInformation -Namespace root/microsoft/Windows/DesiredStateConfiguration -Property @{ RequireHostFileEntry = "false"; HostEntryName = "www.mysite.com"; HostIpAddress = "192.168.200.1" } -ClientOnly)

        It "leaves the hosts file unchanged" {
            Set-Content $hostsFilePath -value "192.168.200.3    www.othersite.com"
            Set-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo -HostFileInfo $hostFileInfo
            (Get-Content $hostsFilePath) -join "`n" | Should Be "192.168.200.3    www.othersite.com"
        }
    }


}