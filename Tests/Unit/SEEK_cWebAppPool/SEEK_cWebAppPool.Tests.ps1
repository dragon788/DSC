$module = Join-Path $PSScriptRoot "..\..\..\Modules\cWebAdministration\DSCResources\SEEK_cWebAppPool\SEEK_cWebAppPool.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

$MockAppPool = New-Object PSObject
$MockAppPool | Add-Member PSPath "IIS:\AppPools\MyAppPool"
$MockAppPool | Add-Member Ensure "Present"
$MockAppPool | Add-Member Name "MyAppPool"
$MockAppPool | Add-Member State "Started"
$MockAppPool | Add-Member managedRuntimeVersion "v4.0"
$MockAppPool | Add-Member managedPipelineMode "Integrated"
$MockAppPool | Add-Member enable32BitAppOnWin64 $false
$MockAppPool | Add-Member processModel @{identityType = "SpecificUser"; userName = "Bob"; password = "Password123"}

Describe "Get-TargetResource" {
    Context "when application pool is present" {
        Mock Get-Item {return @($MockAppPool)} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "returns the application pool state as a hashtable" {
            $AppPool = Get-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication"
            $AppPool.Name | Should Be "MyAppPool"
            $AppPool.Ensure | Should Be "Present"
            $AppPool.State | Should Be "Started"
            $AppPool.managedRuntimeVersion | Should Be "v4.0"
            $AppPool.managedPipelineMode | Should Be "Integrated"
            $AppPool.enable32BitAppOnWin64 | Should Be $false
            $AppPool.processModel.identityType | Should Be "SpecificUser"
            $AppPool.processModel.userName | Should Be "bob"
            $AppPool.processModel.password | Should Be "Password123"
        }
    }

    Context "when application pool is absent" {
        Mock Get-Item {return @()} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "Get-TargetResource returns an absent application pool hashtable" {
            $AppPool = Get-TargetResource -Name "NewAppPool" -ApplicationName "MyApplication"
            $AppPool.Name | should be "NewAppPool"
            $AppPool.Ensure | should be "Absent"
            $AppPool.State | should be "Stopped"
        }
    }
}

Describe "Test-TargetResource" {
    Context "when the application pool is in the desired state" {
        Mock Get-Item {return @($MockAppPool)} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "returns true" {
            $result = Test-TargetResource `
                -Name "MyAppPool" `
                -ApplicationName "MyApplication" `
                -ManagedRuntimeVersion "v4.0" `
                -ManagedPipelineMode "Integrated" `
                -Enable32BitAppOnWin64 "False" `
                -IdentityType "SpecificUser" `
                -UserName "Bob" `
                -Password "Password123"
            $result | Should Be $true
        }
    }

    Context "when the application pool differs from the desired state" {
        Mock Get-Item {return @($MockAppPool)} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "returns false if the ManagedRuntimeVersion is different" {
            Test-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -UserName "Bob" -Password "Password123" `
                -ManagedRuntimeVersion "v2.0" | Should Be $false
        }

        It "returns false if the ManagedPipelineMode is different" {
            Test-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -UserName "Bob" -Password "Password123" `
                -ManagedPipelineMode "Classic" | Should Be $false
        }

        It "returns false if the Enable32BitAppOnWin64 is different" {
            Test-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -UserName "Bob" -Password "Password123" `
                -Enable32BitAppOnWin64 $true | Should Be $false
        }

        It "returns false if the IdentityType is different" {
            Test-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -UserName "Bob" -Password "Password123" `
                -IdentityType "LocalSystem" | Should Be $false
        }

        It "returns false if the UserName is different" {
            Test-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -Password "Password123" `
                -UserName "Betty" | Should Be $false
        }

        It "returns false if the Password is different" {
            Test-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -UserName "Bob" `
                -Password "letmein" | Should Be $false
        }
    }

    Context "when application pool is absent" {
        Mock Get-Item {return @()} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "Test-TargetResource returns false" {
            Test-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -UserName "Bob" -Password "letmein" | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {
    Mock Set-Item
    Mock Start-WebAppPool
    Mock New-WebAppPool
    Mock Remove-WebAppPool
    Mock Start-WebAppPool
    Mock Stop-WebAppPool

    Context "when application pool is absent" {
        Mock Get-Item {return @()} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "creates a new application pool" {
            Mock New-WebAppPool {return $MockAppPool} -ParameterFilter {$Name -eq "NewAppPool"}
            Set-TargetResource -Name "NewAppPool" -ApplicationName "MyApplication" -UserName "Bob" -Password "Password123"
            Assert-MockCalled Set-Item 1 {
                $Value.Name -eq "MyAppPool" `
                -and $Value.ManagedRuntimeVersion -eq "v4.0" `
                -and $Value.ManagedPipelineMode -eq "Integrated" `
                -and $Value.Enable32BitAppOnWin64 -eq $false `
                -and $Value.ProcessModel.IdentityType -eq "SpecificUser" `
                -and $Value.ProcessModel.UserName -eq "Bob" `
                -and $Value.ProcessModel.Password -eq "Password123" `
            }
        }
    }

    Context "when application pool is present" {
        Mock Get-Item {return @($MockAppPool)} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "does not create a new application pool" {
            Set-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -UserName "Bob" -Password "Password123"
            Assert-MockCalled New-WebAppPool 0
        }

        It "updates the existing application pool" {
            Set-TargetResource `
                -Name "MyAppPool" `
                -ApplicationName "MyApplication" `
                -ManagedRuntimeVersion "v2.0" `
                -ManagedPipelineMode "Classic" `
                -Enable32BitAppOnWin64 "true" `
                -IdentityType "LocalSystem" `
                -UserName "Betty" `
                -Password "letmein"
            Assert-MockCalled Set-Item 1 {
                $Value.Name -eq "MyAppPool" `
                -and $Value.ManagedRuntimeVersion -eq "v2.0" `
                -and $Value.ManagedPipelineMode -eq "Classic" `
                -and $Value.Enable32BitAppOnWin64 -eq $true `
                -and $Value.ProcessModel.IdentityType -eq "LocalSystem" `
                -and $Value.ProcessModel.UserName -eq "Betty" `
                -and $Value.ProcessModel.Password -eq "letmein"
            }
        }
    }

    Context "when desired state is equal to the application pool state" {
        Mock Get-Item {return @($MockAppPool)} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "does nothing" {
            Set-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -State $MockAppPool.State -UserName "Bob" -Password "Password123"
            Assert-MockCalled Start-WebAppPool 0
            Assert-MockCalled Stop-WebAppPool 0

        }
    }

    Context "when desired state is stopped and application pool is started" {
        $MockAppPool.State = "Started"
        Mock Get-Item {return @($MockAppPool)} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "stops the application pool" {
            Set-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -State "Stopped" -UserName "Bob" -Password "Password123"
            Assert-MockCalled Stop-WebAppPool 1 {$Name -eq "MyAppPool"}
        }
    }

    Context "when desired state is started and application pool is stopped" {
        $MockAppPool.State = "Stopped"
        Mock Get-Item {return @($MockAppPool)} -ParameterFilter {$Path -eq "IIS:\AppPools\*"}

        It "starts the application pool" {
            Set-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -State "Started" -UserName "Bob" -Password "Password123"
            Assert-MockCalled Start-WebAppPool 1 {$Name -eq "MyAppPool"}
        }
    }

    Context "when configuration specifies the application pool should be absent" {
        It "removes the application pool" {
            Set-TargetResource -Name "MyAppPool" -ApplicationName "MyApplication" -Ensure "Absent" -UserName "Bob" -Password "Password123"
            Assert-MockCalled Remove-WebAppPool 1 {$Name -eq "MyAppPool"}
        }
    }
}
