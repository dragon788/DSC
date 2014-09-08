$module = Join-Path $PSScriptRoot "..\..\..\Modules\SEEK - Modules\cWebAdministration\DSCResources\SEEK_cWebVirtualDirectory\SEEK_cWebVirtualDirectory.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

$MockVirtualDirectory = New-Object PSObject -Property @{
    name = "MyVirtualDir"
    physicalPath = "C:\TargetDir"
    logonMethod = "Network"
    username = "Domain\User"
    password = "Pa55word!"
    count = 1
}
$MockWebApplication = New-Object PSObject -Property @{
    name = "MyApplication"
    count = 1
}

Describe "Get-TargetResource" {
    Mock Test-Path { $false }
    Mock Get-Item
    Mock Get-WebApplication

    Context "when the virtual directory exists underneath a website" {
        Mock Test-Path { $true }
        Mock Get-Item { $MockVirtualDirectory } -ParameterFilter {
            $Path -eq "IIS:\Sites\MySite\MyVirtualDir"
        }

        It "returns the virtual directory properties" {
            $virtualDirectory = Get-TargetResource -Website "MySite" -Name "MyVirtualDir"
            $virtualDirectory.Ensure | Should Be "Present"
            $virtualDirectory.Website | Should Be "MySite"
            $virtualDirectory.WebApplication | Should BeNullOrEmpty
            $virtualDirectory.PhysicalPath | Should Be "C:\TargetDir"
            $virtualDirectory.Name | Should Be "MyVirtualDir"
            $virtualDirectory.LogonMethod | Should Be "Network"
            $virtualDirectory.Username | Should Be "Domain\User"
            $virtualDirectory.Password | Should Be "Pa55word!"
        }
    }

    Context "when the virtual directory exists underneath a web application" {
        Mock Test-Path { $true }
        Mock Get-Item { $MockVirtualDirectory } -ParameterFilter {
            $Path -eq "IIS:\Sites\MySite\MyApplication\MyVirtualDir"
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
            $virtualDirectory.LogonMethod | Should Be "Network"
            $virtualDirectory.Username | Should Be "Domain\User"
            $virtualDirectory.Password | Should Be "Pa55word!"
        }
    }

    Context "when the virtual directory path does not exist" {
        Mock Test-Path { $false }
        It "returns an absent hashtable" {
            $virtualDirectory = Get-TargetResource -Website "MySite" -WebApplication "MyApplication" -Name "MyVirtualDir"
            $virtualDirectory.Ensure | Should Be "Absent"
            $virtualDirectory.Website | Should Be "MySite"
            $virtualDirectory.WebApplication | Should Be "MyApplication"
            $virtualDirectory.Name | Should Be "MyVirtualDir"
            $virtualDirectory.LogonMethod | Should BeNullOrEmpty
            $virtualDirectory.Username | Should BeNullOrEmpty
            $virtualDirectory.Password | Should BeNullOrEmpty
        }
    }

    Context "when the virtual directory path exists, but is not a virtual directory" {
        Mock Test-Path { $true }

        $MockVirtualDirectory = New-Object PSObject -Property @{
            name = "MyVirtualDir"
        }

        Mock Get-Item { $MockVirtualDirectory } -ParameterFilter {
            $Path -eq "IIS:\Sites\MySite\MyVirtualDir"
        }

        It "returns an absent hashtable" {
            $virtualDirectory = Get-TargetResource -Website "MySite" -WebApplication "MyApplication" -Name "MyVirtualDir"
            $virtualDirectory.Ensure | Should Be "Absent"
            $virtualDirectory.Website | Should Be "MySite"
            $virtualDirectory.WebApplication | Should Be "MyApplication"
            $virtualDirectory.Name | Should Be "MyVirtualDir"
            $virtualDirectory.LogonMethod | Should BeNullOrEmpty
            $virtualDirectory.Username | Should BeNullOrEmpty
            $virtualDirectory.Password | Should BeNullOrEmpty
        }
    }

}

Describe "Test-TargetResource" {
    Mock Get-WebApplication
    Mock Get-Item
    Mock Test-Path { $false }

    Context "when the virtual directory does not exist" {
        Mock Test-Path { $false }

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
        Mock Test-Path { $true }
        Mock Get-Item { $MockVirtualDirectory } -ParameterFilter {
            $Path -eq "IIS:\Sites\MySite\MyVirtualDir"
        }

        It "returns true if the virtual directory matches the desired state" {
            Test-TargetResource -Website "MySite" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir" `
                -LogonMethod "Network" `
                -Username "Domain\User" `
                -Password "Pa55word!" | Should Be $true
        }

        It "returns false if the physical path is different" {
            Test-TargetResource -Website "MySite" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\Other" `
                -LogonMethod "Network" `
                -Username "Domain\User" `
                -Password "Pa55word!" | Should Be $false
        }

        It "returns false if the logon method is different" {
            Test-TargetResource -Website "MySite" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir" `
                -LogonMethod "ClearText" `
                -Username "Domain\User" `
                -Password "Pa55word!" | Should Be $false
        }

        It "returns false if the username is different" {
            Test-TargetResource -Website "MySite" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir" `
                -LogonMethod "Network" `
                -Username "OtherDomain\User" `
                -Password "Pa55word!" | Should Be $false
        }

        It "returns false if the password is different" {
            Test-TargetResource -Website "MySite" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir" `
                -LogonMethod "Network" `
                -Username "Domain\User" `
                -Password "BadPassword" | Should Be $false
        }

        It "returns false if the desired state is absent" {
            Test-TargetResource -Website "MySite" `
                -Ensure "Absent" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir" `
                -LogonMethod "Network" `
                -Username "Domain\User" `
                -Password "Pa55word!" | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {
    Mock Get-WebApplication
    Mock Get-Item
    Mock Test-Path { $false }

    Context "when the desired state is absent and the virtual directory does not exist" {
        Mock Test-Path { $false }

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
        Mock Test-Path { $false }
        Mock Set-ItemProperty

        It "creates a new virtual directory" {
            Mock New-WebVirtualDirectory {} -Verifiable -ParameterFilter {
                $Name -eq "MyVirtualDir" -and $Site -eq "MySite" -and $PhysicalPath -eq "C:\TargetDir"
            }
            Set-TargetResource -Website "MySite" -Name "MyVirtualDir" -PhysicalPath "C:\TargetDir"
            Assert-VerifiableMocks
        }

        It "sets the logon method" {
            Mock New-WebVirtualDirectory
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite\MyApplication\MyVirtualDir" -and `
                $Name -eq "logonMethod" -and `
                $Value -eq 2
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir" `
                -LogonMethod "Network"
            Assert-VerifiableMocks
        }

        It "sets the credentials" {
            Mock New-WebVirtualDirectory
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite\MyApplication\MyVirtualDir" -and `
                $Name -eq "username" -and `
                $Value -eq "Domain\User"
            }
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite\MyApplication\MyVirtualDir" -and `
                $Name -eq "password" -and `
                $Value -eq "Pa55word!"
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir" `
                -Username "Domain\User" `
                -Password "Pa55word!"
            Assert-VerifiableMocks
        }
    }

    Context "when a virtual directy exists with the same name" {
        Mock Test-Path { $true }
        Mock Set-ItemProperty
        Mock Get-Item { $MockVirtualDirectory } -ParameterFilter {
            $Path -eq "IIS:\Sites\MySite\MyApplication\MyVirtualDir"
        }
        Mock Get-WebApplication { $MockWebApplication } -ParameterFilter {
            $Name -eq "MyApplication" -and $Site -eq "MySite"
        }

        It "updates the physical path of the virtual directory" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite\MyApplication\MyVirtualDir" -and `
                $Name -eq "physicalPath" -and `
                $Value -eq "C:\NewTargetDir"
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir"
            Assert-VerifiableMocks
        }

        It "updates the logon method" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite\MyApplication\MyVirtualDir" -and `
                $Name -eq "logonMethod" -and `
                $Value -eq 2
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir" `
                -LogonMethod "Network"
            Assert-VerifiableMocks
        }

        It "updates the credentials" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite\MyApplication\MyVirtualDir" -and `
                $Name -eq "username" -and `
                $Value -eq "Domain\User"
            }
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Path -eq "IIS:\Sites\MySite\MyApplication\MyVirtualDir" -and `
                $Name -eq "password" -and `
                $Value -eq "Pa55word!"
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir" `
                -Username "Domain\User" `
                -Password "Pa55word!"
            Assert-VerifiableMocks
        }
    }

    Context "when the desired state is absent and the virtual directory exists" {
        Mock Test-Path { $true }
        Mock Get-Item { $MockVirtualDirectory } -ParameterFilter {
            $Path -eq "IIS:\Sites\MySite\MyVirtualDir"
        }

        It "removes the virtual directory" {
            Mock Remove-WebVirtualDirectory -Verifiable -ParameterFilter {
                $Site -eq "MySite" -and !$Application -and $Name -eq "MyVirtualDir"
            }
            Set-TargetResource -Website "MySite" `
                -Ensure "Absent" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\TargetDir"
            Assert-VerifiableMocks
        }
    }

    Context "when setting the logon method enumeration" {
        Mock New-WebVirtualDirectory
        Mock Set-ItemProperty

        It "sets a value of 0 if the logonMethod is 'Batch'" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Name -eq "logonMethod" -and `
                $Value -eq 0
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir" `
                -LogonMethod "Batch"
            Assert-VerifiableMocks
        }

        It "sets a value of 1 if the logonMethod is 'Interactive'" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Name -eq "logonMethod" -and `
                $Value -eq 1
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir" `
                -LogonMethod "Interactive"
            Assert-VerifiableMocks
        
        }

        It "sets a value of 2 if the logonMethod is 'Network'" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Name -eq "logonMethod" -and `
                $Value -eq 2
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir" `
                -LogonMethod "Network"
            Assert-VerifiableMocks
        }

        It "sets a value of 3 if the logonMethod is 'ClearText'" {
            Mock Set-ItemProperty {} -Verifiable -ParameterFilter {
                $Name -eq "logonMethod" -and `
                $Value -eq 3
            }
            Set-TargetResource -Website "MySite" `
                -WebApplication "MyApplication" `
                -Name "MyVirtualDir" `
                -PhysicalPath "C:\NewTargetDir" `
                -LogonMethod "ClearText"
            Assert-VerifiableMocks
        }
    }

    
}

