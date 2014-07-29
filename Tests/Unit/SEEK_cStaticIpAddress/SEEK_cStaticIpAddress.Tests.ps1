$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cNetworking\DSCResources\SEEK_cStaticIpAddress\SEEK_cStaticIpAddress.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Mock Get-WmiObject { $MockNetworkAdapters } -ParameterFilter { $Class -eq "Win32_NetworkAdapter" }
Mock Get-WmiObject { $MockNetworkAdapterConfiguration } -ParameterFilter { $Class -eq "Win32_NetworkAdapterConfiguration" }
Mock Enable-Static
Mock Enable-DHCP

Describe "Get-TargetResource" {
    Context "when the IP Address bound to a network interface" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
            IPAddress = @("192.168.0.1")
            IPSubnet = @("255.255.255.0")
            DHCPEnabled = $false
        })

        It "returns the IP Address info as a hashtable" {
            $IpAddress = Get-TargetResource -IpAddress "192.168.0.1"
            $IpAddress.Ensure | Should Be "Present"
            $IpAddress.IpAddress | Should Be "192.168.0.1"
            $IpAddress.Interface | Should Be "My Interface"
            $IpAddress.SubnetMask | Should Be "255.255.255.0"
            $IpAddress.DHCPEnabled | Should Be $false
        }
    }

    Context "when the network interface has multiple IP addresses" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
            IPAddress = @("192.168.0.1", "10.0.0.1")
            IPSubnet = @("255.255.255.0", "255.255.0.0")
        })

        It "returns only the IP address we are interested in" {
            $IpAddress = Get-TargetResource -IpAddress "192.168.0.1"
            $IpAddress.IpAddress | Should Be "192.168.0.1"
        }

        It "returns the subnet mask associated with the desired IP address" {
            $IpAddress = Get-TargetResource -IpAddress "192.168.0.1"
            $IpAddress.SubnetMask | Should Be "255.255.255.0"
        }
    }

    Context "when the IP Address is not bound to any network interfaces" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 11
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 11
            IPAddress = @("10.0.0.1")
            IPSubnet = @("255.255.255.0")
            DHCPEnabled = $false
        })

        It "returns an absent hashtable" {
            $IpAddress = Get-TargetResource -IpAddress "192.168.0.1"
            $IpAddress.Ensure | Should Be "Absent"
            $IpAddress.IpAddress | Should Be "192.168.0.1"
            $IpAddress.Interface | Should Be $null
            $IpAddress.SubnetMask | Should Be $null
            $IpAddress.DHCPEnabled | Should Be $null
        }
    }
}

Describe "Test-TargetResource" {
    Context "when the IP Address is bound to a network interface" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
            IPAddress = @("192.168.0.1")
            IPSubnet = @("255.255.255.0")
            DHCPEnabled = $false
        })

        It "returns true if the IP address is bound with the correct interface and subnet mask" {
            Test-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" | Should Be $true
        }

        It "returns false if the IP address should be absent" {
            Test-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" -Ensure "Absent" | Should Be $false
        }

        It "returns false if the Interface is different" {
            Test-TargetResource -IpAddress "192.168.0.1" -Interface "Other Interface" -SubnetMask "255.255.255.0" | Should Be $false
        }

        It "returns false if the SubnetMask is different" {
            Test-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.0.0.0" | Should Be $false
        }
    }

    Context "when the IP Address is not bound to any network interfaces" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
            IPAddress = @("10.0.0.1")
            IPSubnet = @("255.0.0.0")
            DHCPEnabled = $false
        })

        It "returns false if the IP address should be present" {
            Test-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" | Should Be $false
        }

        It "returns true if the IP address should be absent" {
            Test-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" -Ensure "Absent" | Should Be $true
        }
    }

    Context "when the interface does not exist" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
            IPAddress = @("192.168.0.1")
            IPSubnet = @("255.255.255.0")
            DHCPEnabled = $false
        })

        It "returns false" {
            Test-TargetResource -IpAddress "192.168.0.1" -Interface "Other Interface" -SubnetMask "255.255.255.0" | Should Be $false
        }
    }

    Context "when the network adapter is configured for DHCP" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
            IPAddress = @("192.168.0.1")
            IPSubnet = @("255.255.255.0")
            DHCPEnabled = $true
        })

        It "returns false" {
            Test-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {
    Context "when the network interface has a single static IP addresses, equal to the desired address" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
            IPAddress = @("192.168.0.1")
            IPSubnet = @("255.255.255.0")
            DHCPEnabled = $false
        })

        It "does nothing if the IP address should be present" {
            Set-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" -Ensure "Present"
            Assert-MockCalled Enable-Static 0
        }

        It "reverts the interface to DHCP if IP address should be absent" {
            Mock Enable-DHCP {} -Verifiable -ParameterFilter {
                $NetworkAdapterConfiguration.Index -eq 12
            }
            Set-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" -Ensure "Absent"
            Assert-VerifiableMocks
        }
    }

    Context "when the network interface has multiple static IP addresses, including the desired address" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
                IPAddress = @("192.168.0.1", "192.168.0.2")
                IPSubnet = @("255.255.255.0", "255.255.255.0")
                DHCPEnabled = $false
            }
        )

        It "does nothing if the IP address should be present" {
            Set-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" -Ensure "Present"
            Assert-MockCalled Enable-Static 0
        }

        It "removes the IP address from the network interface if the IP address should be absent" {
            Mock Enable-Static {} -Verifiable -ParameterFilter {
                $NetworkAdapterConfiguration.Index -eq 12 -and `
                @(Compare-Object $IpAddresses @("192.168.0.2")).Length -eq 0 -and `
                @(Compare-Object $IpSubnets @("255.255.255.0")).Length -eq 0
            }
            Set-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" -Ensure "Absent"
            Assert-VerifiableMocks
        }
    }

    Context "when the IP Address is not bound to any network interface" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
            IPAddress = @("192.168.0.1")
            IPSubnet = @("255.255.255.0")
            DHCPEnabled = $false
        })

        It "adds the IP address to the desired network interface" {
            Mock Enable-Static {} -Verifiable -ParameterFilter {
                $NetworkAdapterConfiguration.Index -eq 12 -and `
                @(Compare-Object $IpAddresses @("192.168.0.1", "192.168.0.2")).Length -eq 0 -and `
                @(Compare-Object $IpSubnets @("255.255.255.0", "255.255.255.0")).Length -eq 0
            }
            Set-TargetResource -IpAddress "192.168.0.2" -Interface "My Interface" -SubnetMask "255.255.255.0"
            Assert-VerifiableMocks
        }
    }

    Context "when the IP Address is bound to a different network interface" {
        $MockNetworkAdapters = @(
            New-Object PSObject -Property @{
                NetConnectionID = "Old Interface"
                Index = 13
            }
            New-Object PSObject -Property @{
                NetConnectionID = "New Interface"
                Index = 14
            }
        )
        $MockNetworkAdapterConfiguration = @(
            New-Object PSObject -Property @{
                Index = 13
                IPAddress = @("192.168.0.1", "192.168.0.2")
                IPSubnet = @("255.255.255.0", "255.255.255.0")
                DHCPEnabled = $false
            }
            New-Object PSObject -Property @{
                Index = 14
                IPAddress = @("192.168.0.3")
                IPSubnet = @("255.255.255.0")
                DHCPEnabled = $false
            }
        )

        It "removes the IP address from the old network interface" {
            Mock Enable-Static {} -Verifiable -ParameterFilter {
                $NetworkAdapterConfiguration.Index -eq 13 -and `
                @(Compare-Object $IpAddresses @("192.168.0.2")).Length -eq 0 -and `
                @(Compare-Object $IpSubnets @("255.255.255.0")).Length -eq 0
            }
            Set-TargetResource -IpAddress "192.168.0.1" -Interface "New Interface" -SubnetMask "255.255.255.0"
            Assert-VerifiableMocks
        }

        It "associates the IP address with the new network interface" {
            Mock Enable-Static {} -Verifiable -ParameterFilter {
                $NetworkAdapterConfiguration.Index -eq 14 -and `
                @(Compare-Object $IpAddresses @("192.168.0.3", "192.168.0.1")).Length -eq 0 -and `
                @(Compare-Object $IpSubnets @("255.255.255.0", "255.255.255.0")).Length -eq 0
            }
            Set-TargetResource -IpAddress "192.168.0.1" -Interface "New Interface" -SubnetMask "255.255.255.0"
            Assert-VerifiableMocks
        }
    }

    Context "when the network interface is bound to IPv6 address" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
                IPAddress = @("192.168.0.1", "fe80::4dfd:4910:d32d:b61a")
                IPSubnet = @("255.255.255.0", 64)
                DHCPEnabled = $false
            }
        )

        It "adds the IPv4 address to the desired network interface" {
            Mock Enable-Static {} -Verifiable -ParameterFilter {
                $NetworkAdapterConfiguration.Index -eq 12 -and `
                @(Compare-Object $IpAddresses @("192.168.0.1", "192.168.0.2")).Length -eq 0 -and `
                @(Compare-Object $IpSubnets @("255.255.255.0", "255.255.255.0")).Length -eq 0
            }
            Set-TargetResource -IpAddress "192.168.0.2" -Interface "My Interface" -SubnetMask "255.255.255.0"
            Assert-VerifiableMocks
        }
    }

    Context "when configuration specifies the IP address should be absent" {
        $MockNetworkAdapters = @(New-Object PSObject -Property @{
            NetConnectionID = "My Interface"
            Index = 12
        })
        $MockNetworkAdapterConfiguration = @(New-Object PSObject -Property @{
            Index = 12
                IPAddress = @("192.168.0.1", "192.168.0.2")
                IPSubnet = @("255.255.255.0", "255.255.255.0")
                DHCPEnabled = $false
            }
        )

        It "does nothing if the IP address is not bound to the network interface" {
            Mock Enable-Static {}
            Set-TargetResource -IpAddress "192.168.0.3" -Interface "My Interface" -SubnetMask "255.255.255.0" -Ensure "Absent"
            Assert-MockCalled Enable-Static 0
        }

        It "removes the IP address from the network interface" {
            Mock Enable-Static {} -Verifiable -ParameterFilter {
                $NetworkAdapterConfiguration.Index -eq 12 -and `
                @(Compare-Object $IpAddresses @("192.168.0.2")).Length -eq 0 -and `
                @(Compare-Object $IpSubnets @("255.255.255.0")).Length -eq 0
            }
            Set-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "255.255.255.0" -Ensure "Absent"
            Assert-VerifiableMocks
        }
    }

    Context "when the interface does not exist" {
        $MockNetworkAdapters = @()
        $MockNetworkAdapterConfiguration = @()

        It "throws an error" {
            { Set-TargetResource -IpAddress "192.168.0.1" -Interface "Foo Interface" -SubnetMask "255.255.255.0" } | Should Throw
        }
    }

    Context "when the IpAddress is invaid" {
        It "throws an error" {
            { Set-TargetResource -IpAddress "256.256.256.256" -Interface "My Interface" -SubnetMask "255.255.255.0" }  | Should Throw
        }
    }

    Context "when the subnet mask is invaid" {
        It "throws an error" {
            { Set-TargetResource -IpAddress "192.168.0.1" -Interface "My Interface" -SubnetMask "256.256.256.256" }  | Should Throw
        }
    }
}
