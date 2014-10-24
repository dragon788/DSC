[Environment]::SetEnvironmentVariable("PSModulePath", "${PSScriptRoot}\Modules;" + $env:PSModulePath, "Process")

$module = Join-Path $PSScriptRoot "..\..\..\Modules\SEEK - Modules\cAppFabricHosting\DSCResources\SEEK_cApplicationAutoStart\SEEK_cApplicationAutoStart.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Get-TargetResource" {
    Mock Get-ASApplication

    Context "when auto start is enabled for all" {
        Mock Get-ASApplication { @{AutoStartMode = "All"} }

        It "returns the application auto start state as a hashtable" {
            $application = Get-TargetResource -Website "MySite" -Name "MyApp"
            $application.WebSite | Should Be "MySite"
            $application.Name | Should Be "MyApp"
            $application.Ensure | should be "Present"
            $application.AutoStartMode | Should Be "All"
        }
    }

    Context "when auto start is disabled" {
        Mock Get-ASApplication { @{AutoStartMode = "Disable"} }

        It "returns an absent application auto start hashtable" {
            $application = Get-TargetResource -Website "MySite" -Name "MyApp"
            $application.WebSite | Should Be "MySite"
            $application.Name | Should Be "MyApp"
            $application.Ensure | should be "Absent"
            $application.AutoStartMode | Should Be "Disable"
        }
    }

    Context "when auto start is absent" {
        Mock Get-ASApplication { @{AutoStartMode = $null} }

        It "returns an absent application auto start hashtable" {
            $application = Get-TargetResource -Website "MySite" -Name "MyApp"
            $application.WebSite | Should Be "MySite"
            $application.Name | Should Be "MyApp"
            $application.Ensure | should be "Absent"
            $application.AutoStartMode | Should Be "Disable"
        }
    }
}

Describe "Test-TargetResource" {
    Mock Get-ASApplication

    Context "when application auto start is present" {
        Mock Get-ASApplication { @{AutoStartMode = "All"} }

        It "returns true if the application auto start should be present" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Present" -AutoStartMode "All" | Should Be $true
        }

        It "returns false if the web application should be absent" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Absent" | Should Be $false
        }

        It "returns false if the auto start mode is different" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Present" -AutoStartMode "Custom" | Should Be $false
        }
    }

    Context "when application auto start is absent" {
        Mock Get-ASApplication { $null }

        It "returns false if the web application should be present" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Present" -AutoStartMode "All" | Should Be $false
        }

        It "returns true if application auto start should be absent" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Absent" | Should Be $true
        }
    }
}

Describe "Set-TargetResource" {
    Mock Set-ASApplication
    Mock Get-ASApplication

    Context "when the application is absent" {
        Mock Get-ASApplication { return $null }

        It "creates a new application auto start configuration" {
            Mock Set-ASApplication {} -Verifiable -ParameterFilter {$SiteName -eq "MySite" -and $VirtualPath -eq "MyApp" -and $AutoStartMode -eq "All"}
            Set-TargetResource -Website "MySite" -Name "MyApp" -AutoStartMode "All"
            Assert-VerifiableMocks
        }

        It "always enables the application pool" {
            Mock Set-ASApplication {} -Verifiable -ParameterFilter {$EnableApplicationPool -eq $true}
            Set-TargetResource -Website "MySite" -Name "MyApp" -AutoStartMode "All"
            Assert-VerifiableMocks
        }
    }

    Context "when the auto start is present" {
        Mock Get-ASApplication { @{AutoStartMode = "All"} }

        It "updates the auto start mode" {
            Mock Set-ASApplication {} -Verifiable -ParameterFilter {$AutoStartMode -eq "Custom"}
            Set-TargetResource -Website "MySite" -Name "MyApp" -AutoStartMode "Custom"
            Assert-VerifiableMocks
        }
    }

    Context "when configuration specifies the application auto-start should be absent" {
        It "sets the auto start mode to 'Disable' if the auto start is present" {
            Mock Get-ASApplication { @{AutoStartMode = "All"} }
            Mock Set-ASApplication {} -Verifiable -ParameterFilter {$AutoStartMode -eq "Disable"}
            Set-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Absent"
            Assert-VerifiableMocks
        }
    }
}
