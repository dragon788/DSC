$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cHardDisk\DSCResources\SEEK_cSharedDirectory\SEEK_cSharedDirectory.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Get-TargetResource" {
    $shares = @(
        @{Path = "another-share-path"}
        @{Path = "target-share-path"}
    )

    Context "when the shared directory exists" {
        Mock Get-WmiObject { $shares } -ParameterFilter { $Class -eq "Win32_Share" }

        $targetResource = Get-TargetResource -Path "target-share-path"

        It "ensure is present" {
            $targetResource.Ensure | Should Be "Present"
        }

        It "the shared directory matches that requested" {
            $targetResource.SharedDirectory.Path | Should Be "target-share-path"
        }
    }

    Context "when the shared directory does not exsit" {
        Mock Get-WmiObject { $shares } -ParameterFilter { $Class -eq "Win32_Share" }

        $targetResource = Get-TargetResource -Path "not-a-share-path"

        It "ensure is absent" {
            $targetResource.Ensure | Should Be "Absent"
        }

        It "the shared directory is null" {
            $targetResource.SharedDirectory | Should Be $null
        }
    }

    Context "in all cases" {
        Mock Get-WmiObject { $shares } -Verifiable -ParameterFilter { $Class -eq "Win32_Share" }

        It "checks the system for shared directories" {
            Get-TargetResource -Path "another-path"
            Assert-VerifiableMocks
        }
    }
}

Describe "Test-TargetResource" {
    $shares = @(
        @{Path = "another-share-path"}
        @{Path = "target-share-path"}
    )

    Context "when the shared directory exists" {
        Mock Get-WmiObject { $shares } -ParameterFilter { $Class -eq "Win32_Share" }

        It "is true" {
            Test-TargetResource -Path "target-share-path" | Should Be $true
        }
    }

    Context "when the shared directory does not exsit" {
        Mock Get-WmiObject { $shares } -ParameterFilter { $Class -eq "Win32_Share" }

        It "is false" {
            Test-TargetResource -Path "not-a-share-path" | Should Be $false
        }
    }

    Context "in all cases" {
        Mock Get-WmiObject { $shares } -Verifiable -ParameterFilter { $Class -eq "Win32_Share" }

        It "checks the system for shared directories" {
            Test-TargetResource -Path "another-path"
            Assert-VerifiableMocks
        }
    }
}

Describe "Set-TargetResource" {

    $targetPath = "target-share-path"
    $targetDescription = "description"

    $create =
    {
        param($path, $description, $type)
        $this.Result = $path -eq $targetPath -and $description -eq $targetDescription -and $type -eq 0
    }

    $shares = New-Object -TypeName PSObject
    $shares | Add-Member -NotePropertyName Result -NotePropertyValue $false
    $shares | Add-Member -MemberType ScriptMethod -Name Create -Value $create

    Context "when desired state is present, and the path does not exist" {
        Mock Test-Path { $false } -Verifiable -ParameterFilter { $Path -eq $targetPath }
        Mock New-Item {} -Verifiable -ParameterFilter { $Path -eq $targetPath }
        Mock Get-WmiObject { $shares } -Verifiable -ParameterFilter { $Class -eq "Win32_Share" }

        Set-TargetResource -Path $targetPath -Description $targetDescription

        It "creates the directory" {
            Assert-VerifiableMocks
        }

        It "shares the directory" {
            $shares.Result | should be $true
        }
    }

    Context "when the desired state is present, and the path exists" {
        $shares.Result = $false

        Mock Test-Path { $true } -Verifiable -ParameterFilter { $Path -eq $targetPath }
        Mock New-Item {}
        Mock Get-WmiObject { $shares } -Verifiable -ParameterFilter { $Class -eq "Win32_Share" }

        Set-TargetResource -Path $targetPath -Description $targetDescription

        It "does not create the directory" {
            Assert-MockCalled New-Item -Times 0
        }

        It "shares the directory" {
            $shares.Result | should be $true
        }
    }

    Context "when desired state is absent, and the path exists" {
        Mock Test-Path { $true } -Verifiable -ParameterFilter { $Path -eq $targetPath }
        Mock Remove-Item {} -Verifiable -ParameterFilter { $Path -eq $targetPath }
        Set-TargetResource -Ensure "Absent" -Path $targetPath -Description $targetDescription

        It "deletes the shared directory" {
            Assert-VerifiableMocks
        }
    }

    Context "when desired state is absent, and the path does not exist" {
        Mock Test-Path { $false } -ParameterFilter { $Path -eq $targetPath }
        Mock Remove-Item {}
        Set-TargetResource -Ensure "Absent" -Path $targetPath -Description $targetDescription

        It "does not attempt to delete the shared directory" {
            Assert-MockCalled Remove-Item -Times 0
        }
    }
}

