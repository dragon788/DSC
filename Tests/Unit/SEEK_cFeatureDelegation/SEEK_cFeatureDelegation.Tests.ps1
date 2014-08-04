$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cWebAdministration\DSCResources\SEEK_cFeatureDelegation\SEEK_cFeatureDelegation.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Get-TargetResource" {
    Context "when the delegation does not exist" {
        Mock Get-WebConfiguration {$null}

        It "returns an empty hash" {
            (Get-TargetResource -Name "MyFeature").Ensure | Should Be "Absent"
        }
    }

    Context "when the delegation exists" {
        Mock Get-WebConfiguration {New-Object PSObject -Property @{OverrideMode = "Allow"}}

        It "resource is present" {
            (Get-TargetResource -Name "MyFeature").Ensure | Should Be "Present"
        }

        It "returns the resource name" {
            (Get-TargetResource -Name "MyFeature").Name | Should Be "MyFeature"
        }

        It "returns the resource override mode" {
            (Get-TargetResource -Name "MyFeature").OverrideMode | Should Be "Allow"
        }
    }

    Context "always" {
        Mock Get-WebConfiguration {} -Verifiable -ParameterFilter {$Filter -eq "//MyFeature" -and $PSPath -eq "IIS:"}

        It "asks IIS for the configuration" {
            Get-TargetResource -Name "MyFeature"
            Assert-VerifiableMocks
        }
    }
}

Describe "Test-TargetResource" {
    Context "when the feature delegation is in the desired state" {
        Mock Get-WebConfiguration {New-Object PSObject -Property @{OverrideMode = "Allow"}}

        It "is true" {
            Test-TargetResource -Name "MyFeature" -OverrideMode "Allow" | Should Be $true
        }
    }

    Context "when the override mode is different" {
        Mock Get-WebConfiguration {New-Object PSObject -Property @{OverrideMode = "Inherit"}}

        It "is false" {
            Test-TargetResource -Name "MyFeature" -OverrideMode "Allow" | Should Be $false
        }
    }

    Context "when the feature delegation is present" {
        Mock Get-WebConfiguration {New-Object PSObject}

        It "is false if the desired state is absent" {
            Test-TargetResource -Name "MyFeature" -Ensure "Absent" | Should Be $false
        }

    }

    Context "when the feature delegation is absent" {
        Mock Get-WebConfiguration {$null}

        It "is true if the desired state is absent" {
            Test-TargetResource -Name "MyFeature" -Ensure "Absent" | Should Be $true
        }

        It "is false if the desired state is present" {
            Test-TargetResource -Name "MyFeature" -OverrideMode "Allow" -Ensure "Present" | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {
    Context "when desired state is absent" {
        It "sets the override mode to the default" {
            Mock Set-WebConfiguration {} -Verifiable -ParameterFilter {$Filter -eq "//MyFeature" -and $PSPath -eq "IIS:" -and $MetaData -eq "OverrideMode" -and $Value -eq "Inherit"}
            Set-TargetResource -Name "MyFeature" -Ensure "Absent"
            Assert-VerifiableMocks
        }
    }

    Context "when desired state is present" {
        It "applies the override mode to the feature delegation" {
            Mock Set-WebConfiguration {} -Verifiable -ParameterFilter {$Filter -eq "//MyFeature" -and $PSPath -eq "IIS:" -and $MetaData -eq "OverrideMode" -and $Value -eq "Allow"}
            Set-TargetResource -Name "MyFeature" -OverrideMode "Allow"
            Assert-VerifiableMocks
        }
    }
}