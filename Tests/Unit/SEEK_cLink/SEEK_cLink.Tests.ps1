$module = Join-Path $PSScriptRoot "..\..\..\Modules\SEEK - Modules\cHardDisk\DSCResources\SEEK_cLink\SEEK_cLink.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Get-TargetResource" {
    Context "when the link exists" {
        Mock Test-Path { $true }

        It "ensure is present" {
            (Get-TargetResource -Link "existing-link").Ensure | Should Be "Present"
        }
    }

    Context "when the link does not exist" {
        Mock Test-Path { $false }

        It "ensure is absent" {
            (Get-TargetResource -Link "not-a-link").Ensure | Should Be "Absent"
        }
    }
}

Describe "Test-TargetResource" {
    Context "when the link exists" {
        Mock Test-Path { $true }

        It "is true, when ensure is present" {
            (Test-TargetResource -Type "/D" -Link "existing-link" -Target "target") | Should Be $true
        }

        It "is false, when ensure is absent" {
            (Test-TargetResource -Type "/D" -Link "existing-link" -Target "target" -Ensure "Absent") | Should Be $false
        }
    }

    Context "when the link does not exist" {
        Mock Test-Path { $false }

        It "is false, when ensure is present" {
            (Test-TargetResource -Type "/D" -Link "not-a-link" -Target "target") | Should Be $false
        }

        It "is true, when ensure is absent" {
            (Test-TargetResource -Type "/D" -Link "not-a-link" -Target "target" -Ensure "Absent") | Should Be $true
        }
    }
}

Describe "Set-TargetResource" {
    $testRoot = (Get-PSDrive TestDrive).Root
    MkDir "${testRoot}\the-target" | Out-Null
    Echo $null > "${testRoot}\the-target\a-file"
    cmd /c mklink "/D" "${testRoot}\new-link" "${testRoot}\the-target" | Out-Null

    Context "when desired state is absent" {
        It "deletes the link" {
            Set-TargetResource -Ensure "Absent" -Type "/D" -Link "${testRoot}\new-link" -Target "${testRoot}\the-target"
            Test-Path "${testRoot}\new-link" | Should Be $false
        }
    }

    Context "when desired state is present" {
        It "makes the link" {
            Set-TargetResource -Type "/D" -Link "${testRoot}\new-link" -Target "${testRoot}\the-target"
            Test-Path "${testRoot}\new-link\a-file" | Should Be $true
        }
    }
}
