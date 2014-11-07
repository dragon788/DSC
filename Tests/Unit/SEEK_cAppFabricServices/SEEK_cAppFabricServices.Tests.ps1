[Environment]::SetEnvironmentVariable("PSModulePath", "${PSScriptRoot}\Modules;" + $env:PSModulePath, "Process")

$module = Join-Path $PSScriptRoot "..\..\..\Modules\SEEK - Modules\cAppFabricHosting\DSCResources\SEEK_cAppFabricServices\SEEK_cAppFabricServices.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Get-TargetResource" {
    Mock Get-Service

    Context "when all AppFabric services are running" {
        Mock Get-Service { New-Object PSObject -Property @{Status = "Running"} }

        It "returns an present hashtable" {
            $service = Get-TargetResource -Index 0
            $service.Ensure | should be "Present"
        }
    }

    Context "when only some of the AppFabric services are running" {
        Mock Get-Service { New-Object PSObject -Property @{Status = "Running"} } -ParameterFilter {$Name -eq "AppFabricWorkflowManagementService"}
        Mock Get-Service { New-Object PSObject -Property @{Status = "Stopped"} } -ParameterFilter {$Name -eq "AppFabricEventCollectionService"}

        It "returns an absent hashtable" {
            $service = Get-TargetResource -Index 0
            $service.Ensure | should be "Absent"
        }
    }

    Context "when all AppFabric services are stopped" {
        Mock Get-Service { New-Object PSObject -Property @{Status = "Stopped"} }

        It "returns a absent hashtable" {
            $service = Get-TargetResource -Index 0
            $service.Ensure | should be "Absent"
        }
    }
}

Describe "Test-TargetResource" {
    Mock Get-Service

    Context "when all AppFabric services are running" {
        Mock Get-Service { New-Object PSObject -Property @{Status = "Running"} }

        It "returns true if the service should be present/enabled" {
            Test-TargetResource -Index 0 -Ensure "Present" | should be $true
        }

        It "returns false if the service should be absent/disabled" {
            Test-TargetResource -Index 0 -Ensure "Absent" | should be $false
        }
    }

    Context "when all AppFabric services are stopped" {
        Mock Get-Service { New-Object PSObject -Property @{Status = "Stopped"} }

        It "returns false if the service should be present/enabled" {
            Test-TargetResource -Index 0 -Ensure "Present" | should be $false
        }

        It "returns true if the service should be absent/disabled" {
            Test-TargetResource -Index 0 -Ensure "Absent" | should be $true
        }
    }
}

Describe "Set-TargetResource" {
    Mock Get-Service
    Mock Stop-Service
    Mock Start-Service

    Context "when AppFabric services should absent/disabled" {
        $ensure = "Absent"

        It "stops all the AppFabric services" {
            Mock Stop-Service {} -Verifiable -ParameterFilter {$Name -eq "AppFabricWorkflowManagementService"}
            Mock Stop-Service {} -Verifiable -ParameterFilter {$Name -eq "AppFabricEventCollectionService"}
            Set-TargetResource -Index 0 -Ensure $ensure
            Assert-VerifiableMocks
        }
    }

    Context "when AppFabric services should be present/enabled" {
        $ensure = "Present"

        It "starts all the AppFabric services" {
            Mock Start-Service {} -Verifiable -ParameterFilter {$Name -eq "AppFabricWorkflowManagementService"}
            Mock Start-Service {} -Verifiable -ParameterFilter {$Name -eq "AppFabricEventCollectionService"}
            Set-TargetResource -Index 0 -Ensure $ensure
            Assert-VerifiableMocks
        }
    }
}
