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

$MockBinding = New-Object PSObject -Property @{
    bindingInformation = "192.168.200.1:443:www.mysite.com"
    protocol = "https"
    certificateHash = "35425345"
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
        Mock Get-ItemProperty {New-Object PSObject -Property @{Collection = @($MockBinding)}} `
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
            $WebSite.BindingInfo.CertificateThumbprint | Should Be "35425345"
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