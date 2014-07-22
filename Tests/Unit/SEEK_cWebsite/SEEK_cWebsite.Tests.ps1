$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cWebAdministration\DSCResources\SEEK_cWebsite\SEEK_cWebsite.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Mock Get-Website {return $null}
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
    #Test-TargetResource -Name -PhysicalPath -ApplicationPool -BindingInfo -HostFileInfo -AuthenticationInfo
    Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
        -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("AnonymousAuthentication")}
    Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
        -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("BasicAuthentication")}
    Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $false}} `
        -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("DigestAuthentication")}
    Mock Get-WebConfigurationProperty {New-Object PSObject -Property @{Value = $true}} `
        -ParameterFilter {$Filter -ne $null -and $Filter.EndsWith("WindowsAuthentication")}
    Mock Get-ItemProperty {"C:\foo"} -ParameterFilter {$Path -eq "IIS:\Sites\MySite" -and $Name -eq "physicalPath"}
    Mock Get-Website {New-Object PSObject -Property @{name = "MySite"; state = "Started"; physicalPath = "C:\foo"; applicationPool = "MyAppPool"; count = 1}}
    $AuthenticationInfo = New-CimInstance -ClassName SEEK_cWebAuthenticationInformation -ClientOnly `
        -Property @{Anonymous = $true; Basic = $false; Digest = $false; Windows = $true}
    $BindingInfo = @(
        New-CimInstance -ClassName SEEK_cWebBindingInformation -Namespace root/microsoft/Windows/DesiredStateConfiguration -Property @{Port=[System.UInt16]443;Protocol="https";IPAddress="192.168.200.1";HostName="www.mysite.com";CertificateThumbprint="6CAE3EB1EAE470FA836B350E227B3AE2E9B6F93E";CertificateStoreName="Cert://localmachine/my"} -ClientOnly
        New-CimInstance -ClassName SEEK_cWebBindingInformation -Namespace root/microsoft/Windows/DesiredStateConfiguration -Property @{Port=[System.UInt16]80;Protocol="http";IPAddress="192.168.0.1";HostName="www.mysite.com"} -ClientOnly
    )
    Mock Get-WebBinding {@($MockHttpsBinding, $MockHttpBinding)}

    Context "when the web site is in the desired state" {
        It "returns true" {
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo | Should Be $true
        }
    }

    Context "when the web site differs from the desired state" {

        It "returns false if the physical path is different" {
            Mock Get-Website {New-Object PSObject -Property @{name = "MySite"; state = "Started"; physicalPath = "C:\foo"; count = 1}}
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\bar" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo | Should Be $false
        }

        It "returns false if the state is different" {
            Test-TargetResource -Name "MySite" -State "Stopped" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo | Should Be $false
        }

        It "returns false if the application pool is different" {
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "OtherAppPool" -AuthenticationInfo $AuthenticationInfo | Should Be $false
        }

        It "returns false if the bindings are different" {
            $BindingInfo = @(
                New-CimInstance -ClassName SEEK_cWebBindingInformation -Namespace root/microsoft/Windows/DesiredStateConfiguration -Property @{Port=[System.UInt16]443;Protocol="https";IPAddress="192.168.200.1";HostName="www.mysite.com";CertificateThumbprint="6CAE3EB1EAE470FA836B350E227B3AE2E9B6F93E";CertificateStoreName="Cert://localmachine/my"} -ClientOnly
                New-CimInstance -ClassName SEEK_cWebBindingInformation -Namespace root/microsoft/Windows/DesiredStateConfiguration -Property @{Port=[System.UInt16]80;Protocol="http";IPAddress="192.168.0.2";HostName="www.mysite.com"} -ClientOnly
            )
            Test-TargetResource -Name "MySite" -PhysicalPath "C:\foo" -ApplicationPool "MyAppPool" -AuthenticationInfo $AuthenticationInfo -BindingInfo $BindingInfo | Should Be $false
        }
    }
}