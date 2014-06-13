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
    }
}

Describe "WebSite DSC Resource" {
    Context "when web site is absent" {

        Remove-WebSite "Test" -ErrorAction Ignore
        Remove-WebAppPool "Test" -ErrorAction Ignore
        mkdir C:\inetpub\wwwroot\test | Out-Null
        TestConfiguration -OutputPath .\tmp | Out-Null
        Start-DscConfiguration -Wait -Verbose -Path .\tmp

        It "creates a new application pool" {
            $AppPoolState = Get-WebAppPoolState "Test"
            $AppPoolState.Value | Should Be "Started"
        }

        It "creates a new site" {
            $WebsiteState = Get-WebsiteState "Test"
            $WebsiteState.Value | Should Be "Started"
        }

        Remove-Item -Recurse -Force .\tmp -ErrorAction Ignore | Out-Null
        Remove-WebSite "Test" -ErrorAction Ignore
        Remove-WebAppPool "Test" -ErrorAction Ignore
        Remove-Item -Recurse -Force C:\inetpub\wwwroot\test
    }
}
