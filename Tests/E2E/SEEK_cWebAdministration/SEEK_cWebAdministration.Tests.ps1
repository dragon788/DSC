Import-Module WebAdministration

Configuration TestConfiguration
{
    Import-DscResource -Module cWebAdministration

    Node 'localhost'
    {
        WindowsFeature IIS
        {
            Ensure = "Present"
            Name = "Web-Server"
        }

        cWebAppPool TestAppPool
        {
            Name = "Test"
            ApplicationName = "Test"
            Ensure = "Present"
            State = "Started"
            ManagedRuntimeVersion = "v2.0"
            ManagedPipelineMode = "Classic"
            Enable32BitAppOnWin64 = "True"
            IdentityType = "SpecificUser"
            UserName =  "bob"
            Password = "Password123"
        }

        cWebsite TestWebsite
        {
            Ensure = "Present"
            Name   = "Test"
            ApplicationPool = "Test"
            BindingInfo = @(SEEK_cWebBindingInformation
                            {
                                Protocol = "http"
                                Port = 80
                                HostName = "test.dev"
                            };SEEK_cWebBindingInformation
                            {
                                Protocol = "http"
                                Port = 8080
                                HostName = "test.dev"
                            };SEEK_cWebBindingInformation
                            {
                                Protocol = "net.pipe"
                                HostName = "test.services"
                            };SEEK_cWebBindingInformation
                            {
                                Protocol = "net.tcp"
                                Port = 5555
                                HostName = "test.dev"
                            })
            AuthenticationInfo = SEEK_cWebAuthenticationInformation
                                {
                                    Anonymous = "true"
                                    Basic = "false"
                                    Digest = "false"
                                    Windows = "false"
                                }
            PhysicalPath = "C:\inetpub\wwwroot\test"
            State = "Started"
            DependsOn = @("[cWebAppPool]TestAppPool")
        }

        cWebApplication TestApplication
        {
            Website = "Test"
            Name = "Test"
            WebAppPool = "Test"
            PhysicalPath = "C:\Temp\TestApplication"
            Ensure = "Present"
            AuthenticationInfo = SEEK_cWebAuthenticationInformation
                                {
                                    Anonymous = "true"
                                    Basic = "false"
                                    Digest = "false"
                                    Windows = "false"
                                }
            DependsOn = @("[cWebsite]TestWebsite")
        }

        cWebVirtualDirectory TestVirtualDir
        {
            Name = "Virtual"
            Website = "Test"
            WebApplication = "Test"
            PhysicalPath = "C:\Temp\TestVirtualDir"
            DependsOn = @("[cWebApplication]TestApplication")
        }
    }
}

Describe "WebSite DSC Resource" {
    Context "when web site is absent" {

        Remove-WebAppPool "Test" -ErrorAction Ignore
        Remove-WebApplication -Site "Test" -Name "Test" -ErrorAction Ignore
        Remove-WebSite "Test" -ErrorAction Ignore
        mkdir C:\inetpub\wwwroot\test -ErrorAction Ignore | Out-Null
        mkdir C:\Temp\TestVirtualDir -ErrorAction Ignore | Out-Null
        mkdir C:\Temp\TestApplication -ErrorAction Ignore | Out-Null
        TestConfiguration -Force -OutputPath .\tmp | Out-Null
        Start-DscConfiguration -Wait -Verbose -Path .\tmp

        It "creates a new application pool" {
            $AppPoolState = Get-WebAppPoolState "Test"
            $AppPoolState.Value | Should Be "Started"
        }

        It "creates a new site" {
            $WebsiteState = Get-WebsiteState "Test"
            $WebsiteState.Value | Should Be "Started"
        }

        It "creates a new web application" {
            Get-WebApplication -Site "Test" -Name "Test" | Should Not Be $null
        }

        It "creates a new web application virtual directory " {
            Get-WebVirtualDirectory -Site "Test" -Application "Test" -Name "Virtual" | Should Not Be $null
        }

        Remove-Item -Recurse -Force .\tmp -ErrorAction Ignore | Out-Null
        Remove-WebApplication -Site "Test" -Name "Test" -ErrorAction Ignore
        Remove-WebSite "Test" -ErrorAction Ignore
        Remove-WebAppPool "Test" -ErrorAction Ignore
        Remove-Item -Recurse -Force C:\inetpub\wwwroot\test
        Remove-Item -Recurse -Force C:\Temp\TestVirtualDir
        Remove-Item -Recurse -Force C:\Temp\TestApplication
    }
}
