$module = Join-Path $PSScriptRoot "..\..\..\Modules\\cWebAdministration\DSCResources\SEEK_cFeatureDelegation\SEEK_cFeatureDelegation.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Get-TargetResource" {
    Context "when the delegation does not exist" {
        Mock Get-WebConfiguration {$null}

        It "returns an empty hash" {
            (Get-TargetResource -Section "MySection").Ensure | Should Be "Absent"
        }
    }

    Context "when the delegation is locked" {
        Mock Get-WebConfiguration  {New-Object PSObject -Property @{OverrideMode = "Deny"}}

         It "returns an empty hash" {
            (Get-TargetResource -Section "MySection").Ensure | Should Be "Absent"
        }
    }

    Context "when the delegation is inherited" {
        Mock Get-WebConfiguration  {New-Object PSObject -Property @{OverrideMode = "Inherit"}}

         It "returns an empty hash" {
            (Get-TargetResource -Section "MySection").Ensure | Should Be "Absent"
        }
    }

    Context "when the delegation is unlocked" {
        Mock Get-WebConfiguration {New-Object PSObject -Property @{OverrideMode = "Allow"}}

        It "resource is present" {
            (Get-TargetResource -Section "MySection").Ensure | Should Be "Present"
        }

        It "returns the section" {
            (Get-TargetResource -Section "MySection").Section | Should Be "MySection"
        }
    }

    Context "always" {
        Mock Get-WebConfiguration {} -Verifiable -ParameterFilter {$Filter -eq "MySection" -and $PSPath -eq "IIS:"}

        It "asks IIS for the configuration" {
            Get-TargetResource -Section "MySection"
            Assert-VerifiableMocks
        }
    }
}

Describe "Test-TargetResource" {
    Context "when the feature delegation is unlocked" {
        Mock Get-WebConfiguration {New-Object PSObject -Property @{OverrideMode = "Allow"}}

        It "is true, if the desired state is present" {
            Test-TargetResource -Section "MySection" -Ensure "Present" | Should Be $true
        }

        It "is false, if the desired state is absent" {
            Test-TargetResource -Section "MySection" -Ensure "Absent" | Should Be $false
        }
    }

    Context "when the feature delegation is locked" {
        Mock Get-WebConfiguration {New-Object PSObject -Property @{OverrideMode = "Deny"}}

        It "is true, if the desired state is absent" {
            Test-TargetResource -Section "MySection" -Ensure "Absent" | Should Be $true
        }

         It "is false, if the desired state is present" {
            Test-TargetResource -Section "MySection" -Ensure "Present" | Should Be $false
        }
    }

    Context "when the feature delegation is absent" {
        Mock Get-WebConfiguration {$null}

        It "is true, if the desired state is absent" {
            Test-TargetResource -Section "MySection" -Ensure "Absent" | Should Be $true
        }

        It "is false, if the desired state is present" {
            Test-TargetResource -Section "MySection" -Ensure "Present" | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {
    Context "when desired state is absent" {
        It "locks the feature delegation" {
            Mock Set-WebConfiguration {} -Verifiable -ParameterFilter {$Filter -eq "MySection" -and $PSPath -eq "IIS:" -and $MetaData -eq "OverrideMode" -and $Value -eq "Deny"}
            Set-TargetResource -Section "MySection" -Ensure "Absent"
            Assert-VerifiableMocks
        }
    }

    Context "when desired state is present" {
        It "unlocks the feature delegation" {
            Mock Set-WebConfiguration {} -Verifiable -ParameterFilter {$Filter -eq "MySection" -and $PSPath -eq "IIS:" -and $MetaData -eq "OverrideMode" -and $Value -eq "Allow"}
            Set-TargetResource -Section "MySection"
            Assert-VerifiableMocks
        }
    }
}