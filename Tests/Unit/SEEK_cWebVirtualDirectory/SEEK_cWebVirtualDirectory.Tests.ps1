$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cWebAdministration\DSCResources\SEEK_cWebVirtualDirectory\SEEK_cWebVirtualDirectory.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Get-TargetResource" {
    Mock Get-WebVirtualDirectory
    Mock Get-WebApplication

    $MockVirtualDirectory = New-Object PSObject -Property @{
        name = "MyVirtualDir"
        physicalPath = "C:\TargetDir"
    }
    $MockWebApplication = @(New-Object PSObject -Property @{
        name = "MyApplication"
    })

    Context "when the virtual directory exists underneath a website" {        
        Mock Get-WebVirtualDirectory { $MockVirtualDirectory } -ParameterFilter {
            $Site -eq "MySite" -and $Name -eq "MyVirtualDir"
        }

        It "returns the virtual directory properties" {
            $virtualDirectory = Get-TargetResource -Website "MySite" -Name "MyVirtualDir"
            $virtualDirectory.Ensure | Should Be "Present"
            $virtualDirectory.Website | Should Be "MySite"
            $virtualDirectory.WebApplication | Should Be "MyApplication"
            $virtualDirectory.PhysicalPath | Should Be "C:\TargetDir"
            $virtualDirectory.Name | Should Be "MyVirtualDir"
        }
    }

    Context "when the virtual directory exists underneath a web application" {
        Mock Get-WebVirtualDirectory { $MockVirtualDirectory } -ParameterFilter {
            $Application -eq "MyApplication" -and $Site -eq "MySite" -and $Name -eq "MyVirtualDir"
        }
        Mock Get-WebApplication { $MockWebApplication } -ParameterFilter {
            $Application -eq "MyApplication" -and $Site -eq "MySite"
        }

        It "returns the virtual directory properties" {
            $virtualDirectory = Get-TargetResource -Website "MySite" -WebApplication "MyApplication" -Name "MyVirtualDir"
            $virtualDirectory.Ensure | Should Be "Present"
            $virtualDirectory.Website | Should Be "MySite"
            $virtualDirectory.WebApplication | Should Be "MyApplication"
            $virtualDirectory.PhysicalPath | Should Be "C:\TargetDir"
            $virtualDirectory.Name | Should Be "MyVirtualDir"
        }
    }

    Context "when the composite virtual directory exists and the application does not exist" {
        Mock Get-WebVirtualDirectory { $MockVirtualDirectory } -ParameterFilter {
            $Site -eq "MySite" -and $Name -eq "MyApplication/MyVirtualDir"
        }

        It "returns the virtual directory properties" {
            $virtualDirectory = Get-TargetResource -Website "MySite" -WebApplication "MyApplication" -Name "MyVirtualDir"
            $virtualDirectory.Ensure | Should Be "Present"
            $virtualDirectory.Website | Should Be "MySite"
            $virtualDirectory.WebApplication | Should Be "MyApplication"
            $virtualDirectory.PhysicalPath | Should Be "C:\TargetDir"
            $virtualDirectory.Name | Should Be "MyVirtualDir"
        }
    }

    Context "when the virtual directory does not exist" {
        It "returns an absent hashtable" {
            $virtualDirectory = Get-TargetResource -Website "MySite" -WebApplication "MyApplication" -Name "MyVirtualDir"
            $virtualDirectory.Ensure | Should Be "Absent"
            $virtualDirectory.Website | Should Be "MySite"
            $virtualDirectory.WebApplication | Should Be "MyApplication"
            $virtualDirectory.PhysicalPath | Should Be ""
            $virtualDirectory.Name | Should Be "MyVirtualDir"
        }
    }
}

<#
Describe "Test-TargetResource" {
}

Describe "Set-TargetResource" {
}
#>
