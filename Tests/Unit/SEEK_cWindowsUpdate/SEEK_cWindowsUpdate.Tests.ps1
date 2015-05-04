Import-Module(Join-Path $PSScriptRoot "..\..\..\Modules\cSoftware\DSCResources\SEEK_cWindowsUpdate\SEEK_cWindowsUpdate.psm1")

InModuleScope "SEEK_cWindowsUpdate" {
    $InstalledHotFix = New-Object PSObject
    $InstalledHotFix | Add-Member HotFixID "KB1234"

    Describe "Get-TargetResource" {
        Context "when the update is already installed" {
            Mock Get-HotFix {return @($InstalledHotFix)}

            It "returns the update state as a hashtable" {
                $Update = Get-TargetResource -Update "C:\foo.msu" -Kb $InstalledHotFix.HotFixID
                $Update.Ensure | Should Be "Present"
                $Update.Update | Should Be "C:\foo.msu"
                $Update.Kb | Should Be $InstalledHotFix.HotFixID
            }
        }

        Context "when the update has not been installed" {
            Mock Get-HotFix {return $null}

            It "returns an absent update hashtable" {
                $Update = Get-TargetResource -Update "C:\foo.msu" -Kb "KB4567"
                $Update.Ensure | should be "Absent"
                $Update.Update | should be "C:\foo.msu"
                $Update.Kb | Should Be "KB4567"
            }
        }
    }

    Describe "Test-TargetResource" {
        Context "when the update is already installed" {
            Mock Get-HotFix {return @($InstalledHotFix)}

            It "returns true if the update should be present" {
                Test-TargetResource -Update "C:\foo.msu" -Kb $InstalledHotFix.HotFixID -Ensure "Present" | Should Be $true
            }

            It "returns false if the update should be absent" {
                Mock Get-HotFix {return @($InstalledHotFix)}
                Test-TargetResource -Update "C:\foo.msu" -Kb $InstalledHotFix.HotFixID -Ensure "Absent" | Should Be $false
            }
        }

        Context "when the update has not been installed" {
            Mock Get-HotFix {return $null}

            It "returns false if the update should be present" {
                Test-TargetResource -Update "C:\foo.msu" -Kb "KB4567" -Ensure "Present" | Should Be $false
            }

            It "returns true if the update should be absent" {
                Test-TargetResource -Update "C:\foo.msu" -Kb "KB4567" -Ensure "Absent" | Should Be $true
            }
        }
    }

    Describe "Set-TargetResource" {
        Mock Start-Process

        Context "when the update is not installed" {
            Mock Get-HotFix {return $null}

            It "installs the update" {
                Set-TargetResource -Update "C:\foo.msu" -Kb "KB4567"
                Assert-MockCalled Start-Process -Exactly 1 -ParameterFilter { ($FilePath -eq "${env:WINDIR}\system32\wusa.exe") -and ($ArgumentList -contains "C:\foo.msu") -and ($ArgumentList -notcontains '/uninstall')}
            }
        }

        Context "when the update is already installed" {
            Mock Get-HotFix {return @($InstalledHotFix)}

            It "does nothing" {
                Set-TargetResource -Update "C:\foo.msu" -Kb $InstalledHotFix.HotFixID
                Assert-MockCalled Start-Process -Times 0
            }
        }

        Context "when configuration specifies the update should be absent" {
            It "uninstalls the update if the update is already installed" {
                Mock Get-HotFix {return @($InstalledHotFix)}
                Set-TargetResource -Update "C:\foo.msu" -Kb $InstalledHotFix.HotFixID -Ensure "Absent"
                Assert-MockCalled Start-Process -Exactly 1 -ParameterFilter { ($FilePath -eq "${env:WINDIR}\system32\wusa.exe") -and ($ArgumentList -contains "C:\foo.msu") -and ($argumentList -contains '/uninstall') }
            }
        }

        Context "when the update is a URL" {
            Mock Get-HotFix {return $null}

            It "downloads the update file and then installs the update" {
                Mock Invoke-WebRequest
                Set-TargetResource -Update "http://foo.com/foo.msu" -Kb "KB4567"
                Assert-MockCalled Invoke-WebRequest -Exactly 1 -ParameterFilter { ($Uri -eq "http://foo.com/foo.msu") }
                Assert-MockCalled Start-Process -Exactly 1 -ParameterFilter { ($FilePath -eq "${env:WINDIR}\system32\wusa.exe") -and ($ArgumentList -contains "${env:TEMP}\foo.msu") }
            }
        }
    }
}
