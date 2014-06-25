$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cSoftware\DSCResources\SEEK_cWindowsUpdate\SEEK_cWindowsUpdate.psm1"
$code = Get-Content $module | Out-String
$update = Join-Path $PSScriptRoot "Windows6.1-KB974405-x64.msu"
Invoke-Expression $code

Describe "Install-Update" {

    Context "when update has not been installed" {
        It "installs the update" {
             Test-UpdateInstalled -Kb "KB974405" | Should Be $false
             Install-Update -Update $update
             Start-Sleep -s 60
             Test-UpdateInstalled -Kb "KB974405" | Should Be $true
        }
    }
}

Describe "Uninstall-Update" {
    Context "when update has been installed" {
        It "uninstalls the update" {
             Test-UpdateInstalled -Kb "KB974405" | Should Be $true
             Uninstall-Update -Update $update
             Start-Sleep -s 60
             Test-UpdateInstalled -Kb "KB974405" | Should Be $false
        }
    }
}
