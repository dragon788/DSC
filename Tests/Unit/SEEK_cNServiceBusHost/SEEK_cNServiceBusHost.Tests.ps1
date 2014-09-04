$module = Join-Path $PSScriptRoot "..\..\..\Modules\SEEK - Modules\cNServiceBus\DSCResources\SEEK_cNServiceBusHost\SEEK_cNServiceBusHost.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

$InstalledNServiceBusHost = New-Object PSObject
$InstalledNServiceBusHost | Add-Member Status "Running"
$InstalledNServiceBusHost | Add-Member Name "MyHost"
$InstalledNServiceBusHost | Add-Member DisplayName "My Host"

Mock Get-Service {return $null}

Describe "Get-TargetResource" {
    Context "when the NServiceBus host is already installed" {
        Mock Get-Service {return @($InstalledNServiceBusHost)}
        It "returns the NServiceBus host state as a hashtable" {
            $HostService = Get-TargetResource -ServiceName "MyHost"
            $HostService.ServiceName | Should Be "MyHost"
            $HostService.Ensure | Should Be "Present"
            $HostService.DisplayName | Should Be "My Host"
        }
    }

    Context "when the NServiceBus host has not been installed" {
        It "returns an absent NServiceBus host hashtable" {
            $HostService = Get-TargetResource -ServiceName "MyHost"
            $HostService.Ensure | should be "Absent"
            $HostService.ServiceName | Should Be "MyHost"
            $HostService.DisplayName | Should Be $null
        }
    }
}

Describe "Test-TargetResource" {
    Context "when the NServiceBus host is already installed" {
        Mock Get-Service {return @($InstalledNServiceBusHost)}

        It "returns true if the NServiceBus host should be present" {
            Test-TargetResource -ServiceName "MyHost" -ApplicationRoot "C:\App" -Ensure "Present" | Should Be $true
        }

        It "returns false if the NServiceBus host should be absent" {
            Test-TargetResource -ServiceName "MyHost" -ApplicationRoot "C:\App" -Ensure "Absent" | Should Be $false
        }
    }

    Context "when the NServiceBus host has not been installed" {
        It "returns false if the NServiceBus host should be present" {
            Test-TargetResource -ServiceName "MyHost" -ApplicationRoot "C:\App" -Ensure "Present" | Should Be $false
        }

        It "returns true if the NServiceBus host should be absent" {
            Test-TargetResource -ServiceName "MyHost" -ApplicationRoot "C:\App" -Ensure "Absent" | Should Be $true
        }
    }
}

Describe "Set-TargetResource" {
    Mock Start-Process

    Context "when the NServiceBus host is not installed" {
        It "installs the NServiceBus host" {
            Set-TargetResource -ServiceName "MyHost" `
                -StartManually "true" `
                -Configuration "Release" `
                -ApplicationRoot "C:\App" `
                -DisplayName "My Host" `
                -Description "A host that consumes stuff"
            Assert-MockCalled Start-Process -Exactly 1 `
                -ParameterFilter {
                    ($FilePath -eq "C:\App\bin\Release\NServiceBus.Host.exe") `
                    -and ($ArgumentList -contains "-install") `
                    -and ($ArgumentList -contains "-serviceName=""MyHost""") `
                    -and ($ArgumentList -contains "-displayName=""My Host""") `
                    -and ($ArgumentList -contains "-description=""A host that consumes stuff""") `
                    -and ($ArgumentList -contains "-startManually")
                }
        }
    }

    Context "when the NServiceBus host is already installed" {
        Mock Get-Service {return @($InstalledNServiceBusHost)}

        It "does nothing" {
            Set-TargetResource -ServiceName "MyHost" `
                -Configuration "Release" `
                -ApplicationRoot "C:\App"
            Assert-MockCalled Start-Process -Times 0 `
                -ParameterFilter { ($FilePath -like "*NServiceBus.Host.exe") }
        }
    }

    Context "when configuration specifies the NServiceBus host should be absent" {
        It "uninstalls the NServiceBus host if the NServiceBus host is already installed" {
            Mock Get-Service {return @($InstalledNServiceBusHost)}
            Set-TargetResource -ServiceName "MyHost" `
                -Ensure "Absent" `
                -Configuration "Release" `
                -ApplicationRoot "C:\App"
            Assert-MockCalled Start-Process -Exactly 1 `
                -ParameterFilter {
                    ($FilePath -eq "C:\App\bin\Release\NServiceBus.Host.exe") `
                    -and ($ArgumentList -contains "-uninstall") `
                    -and ($ArgumentList -contains "-serviceName=""MyHost""")
                }
        }
    }
}
