properties {
  $testOutput = ".\Test.xml"
  $outputDir = ".\Output"
  $outputPackageDir = "${outputDir}\Packages"
  $outputModuleManifestDir = "${outputDir}\ModuleManifests"
  $modulesDir = ".\Modules\SEEK - Modules"
  $dscResourcesRoot = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules"
  $version = "0.1.0-dev"
  if ($env:BUILD_VERSION) { $version = "1.0.0.${env:BUILD_VERSION}-dev" }
  if ($env:RELEASE_TAG) { $version = $env:RELEASE_TAG }
}

task default -depends Clean, UnitTest

task Package -depends Clean {
  if (-not (Test-Path $outputPackageDir)) {
    New-Item -ItemType directory -Path $outputPackageDir | Out-Null
  }
  Get-ChildItem *.nuspec -Recurse | Foreach-Object {
    Update-ModuleManifestVersion -Path $_.DirectoryName -Version $version -OutputDir $outputModuleManifestDir
    # chocolatey.cmd does not support paths with spaces, using chocolatey.ps1 instead
    # chocolatey pack expects a package name argument only, quotes are necessary to inject the additional OutputDir argument
    exec { chocolatey.ps1 pack """$($_.FullName)"" -OutputDir $(Resolve-Path $outputPackageDir) -Version $version" }
  }
}

task EnableDeveloperMode {
  Get-ChildItem $modulesDir -attributes Directory | Foreach-Object {
    $linkPath = "$dscResourcesRoot\$($_.Name)"
    $targePath = $_.FullName
    if (Test-Path $linkPath) {
      cmd /c rmdir $linkPath
    }
    cmd /c mklink /j $linkPath $targePath
  }
}

task DisableDeveloperMode {
  Get-ChildItem $modulesDir -attributes Directory | Foreach-Object {
    $linkPath = Resolve-Path "$dscResourcesRoot\$($_.Name)"
    if (Test-Path $linkPath) {
      cmd /c rmdir $linkPath
    }
  }
}

task Install -depends Package {
  exec { chocolatey.cmd install seek-dsc -source $(Resolve-Path $outputPackageDir) }
}

task Reinstall {
  exec { chocolatey.cmd install seek-dsc -source $(Resolve-Path $outputPackageDir) -force }
}

task Uninstall {
  $packageNames = Get-ChildItem *.nuspec -Recurse | Foreach-Object { $_.Basename }
  chocolatey.cmd uninstall @packageNames
}

task UnitTest {
  Invoke-Tests -Path .\Tests\Unit
}

task IntegrationTest {
  Invoke-Tests -Path .\Tests\Integration
}

task E2ETest -depends FlushCache {
  Invoke-Tests -Path .\Tests\E2E
}

task Test {
  Invoke-Tests -Path $testPath -TestName $testName
}

task FlushCache {
  Restart-Service winmgmt -force
}

task Clean {
  if (Test-Path $testOutput) {
    Remove-Item $testOutput
  }
  if (Test-Path $outputDir) {
    Remove-Item $outputDir -Recurse -Force
  }
}

function Invoke-Tests {
  param (
    [parameter(Mandatory = $true)]
    [string]$Path,

    [string]$TestName
  )

  if ($TestName) {
    exec { pester.bat -Path $Path -TestName $TestName }
  }
  else {
    exec { pester.bat -Path $Path }
  }
}

function Update-ModuleManifestVersion {
  param (
    [parameter(Mandatory = $true)]
    [string]$Path,

    [parameter(Mandatory = $true)]
    [string]$OutputDir,

    [parameter(Mandatory = $true)]
    [string]$Version
  )

  if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType directory -Path $OutputDir | Out-Null
  }

  Get-ChildItem -Path $Path -Filter *.psd1 | Foreach-Object {
    $updatedModuleManifestPath = "${OutputDir}\$($_.Name)"
    (Get-Content($_.FullName)) | ForEach-Object {$_ -replace "ModuleVersion\s+=\s+'[\d\.]+'", "ModuleVersion = '$Version'"} | Set-Content($updatedModuleManifestPath)
  }
}
