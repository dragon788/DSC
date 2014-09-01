$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cWebAdministration\DSCResources\SEEK_cWebVirtualDirectory\SEEK_cWebVirtualDirectory.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

$MockVirtualDirectory = New-Object PSObject -Property @{
    name = "MyVirtualDir"
    physicalPath = "C:\TargetDir"
    count = 1
}
$MockWebApplication = New-Object PSObject -Property @{
    name = "MyApplication"
    count = 1
}

Describe "Get-TargetResource" {
    Mock Get-WebVirtualDirectory
    Mock Get-WebApplication

    Context "when the virtual directory exists underneath a website" {        
        Mock Get-WebVirtualDirectory { $MockVirtualDirectory } -ParameterFilter {
            $Site -eq "MySite" -and $Name -eq "MyVirtualDir"
        }

        It "returns the virtual directory properties" {
            $virtualDirectory = Get-TargetResource -Website "MySite" -Name "MyVirtualDir"
            $virtualDirectory.Ensure | Should Be "Present"
            $virtualDirectory.Website | Should Be "MySite"
            $virtualDirectory.WebApplication | Should Be ""
            $virtualDirectory.PhysicalPath | Should Be "C:\TargetDir"
            $virtualDirectory.Name | Should Be "MyVirtualDir"
        }
    }

    Context "when the virtual directory exists underneath a web application" {
        Mock Get-WebVirtualDirectory { $MockVirtualDirectory } -ParameterFilter {
            $Application -eq "MyApplication" -and $Site -eq "MySite" -and $Name -eq "MyVirtualDir"
        }
        Mock Get-WebApplication { $MockWebApplication } -ParameterFilter {
            $Name -eq "MyApplication" -and $Site -eq "MySite"
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


Describe "Test-TargetResource" {
    Mock Get-WebVirtualDirectory
    Mock Get-WebApplication

    Context "when the virtual directory does not exist" {
        Mock Get-WebVirtualDirectory

        It "returns true if the desired state is absent" {
            Test-TargetResource -Website "MySite" `
                -Ensure "Absent" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir" | Should Be $true
        }

        It "returns false if the desired state is present" {
            Test-TargetResource -Website "MySite" `
                -Ensure "Present" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir" | Should Be $false
        }
    }

    Context "when the virtual directory exists" {
        Mock Get-WebVirtualDirectory { $MockVirtualDirectory } -ParameterFilter {
            $Site -eq "MySite" -and $Name -eq "MyVirtualDir"
        }

        It "returns true if the virtual directory matches the desired state" {
            Test-TargetResource -Website "MySite" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir" | Should Be $true
        }

        It "returns false if the physical path is different" {
            Test-TargetResource -Website "MySite" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\Other" | Should Be $false
        }

        It "returns false if the desired state is absent" {
            Test-TargetResource -Website "MySite" `
                -Ensure "Absent" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\Other" | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {
    Mock Get-WebVirtualDirectory
    Mock Get-WebApplication

    Context "when the desired state is absent and the virtual directory does not exist" {
        Mock Get-WebVirtualDirectory

        It "does nothing" {
            Mock Remove-WebVirtualDirectory
            Mock Set-ItemProperty
            Set-TargetResource -Website "MySite" `
                -Ensure "Absent" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir"
            Assert-MockCalled Remove-WebVirtualDirectory -Times 0 
            Assert-MockCalled Set-ItemProperty -Times 0
        }
    }

    Context "when the virtual directory does not exist" {
        Mock Get-WebVirtualDirectory

        It "creates a new virtual directory" {
            Mock New-WebVirtualDirectory {} -Verifiable -ParameterFilter {
                $Name -eq "MyVirtualDir" -and $Site -eq "MySite" -and $PhysicalPath -eq "C:\TargetDir"
            }
            Set-TargetResource -Website "MySite" -Name "MyVirtualDir" -PhysicalPath "C:\TargetDir"
            Assert-VerifiableMocks
        }
    }

    Context "when a virtual directy exists with the same name" {
        Mock Get-WebVirtualDirectory { $MockVirtualDirectory } -ParameterFilter {
            $Application -eq "MyApplication" -and $Site -eq "MySite" -and $Name -eq "MyVirtualDir"
        }
        Mock Get-WebApplication { $MockWebApplication } -ParameterFilter {
            $Name -eq "MyApplication" -and $Site -eq "MySite"
        }

        It "updates the physical path of the virtual directory" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:Sites\MySite\MyApplication\MyVirtualDir" -and `
                $Name -eq "physicalPath" -and `
                $Value -eq "C:\NewTargetDir"
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir"
            Assert-VerifiableMocks
        }
    }

    Context "when the desired state is absent and the virtual directory exists" {
        Mock Get-WebVirtualDirectory { $MockVirtualDirectory } -ParameterFilter {
            $Site -eq "MySite" -and $Name -eq "MyVirtualDir"
        }

        It "removes the virtual directory" {
            Mock Remove-WebVirtualDirectory -Verifiable -ParameterFilter {
                $Site -eq "MySite" -and $Application -eq "" -and $Name -eq "MyVirtualDir"
            }
            Set-TargetResource -Website "MySite" `
                -Ensure "Absent" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir"
            Assert-VerifiableMocks
        }
    }

    
}

