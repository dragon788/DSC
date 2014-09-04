properties {
  $pesterHome = ".\Packages\Pester.2.1.0\tools"
  $pester = "${pesterHome}\bin\pester.bat"
  $chocolateyHome = ".\Packages\chocolatey.0.9.8.27\tools\chocolateyInstall"
  $chocolatey = "${chocolateyHome}\chocolatey.ps1"
  $testOutput = ".\Test.xml"
  $outputDir = ".\Output"
  $outputPackageDir = "${outputDir}\Packages"
  $modulesDir = ".\Modules\SEEK - Modules"
  $dscResourcesRoot = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules"
}

task default -depends Clean, UnitTest, IntegrationTest

task Package <#-depends UnitTest, IntegrationTest#> {
  if (-not (Test-Path $outputPackageDir)) {
    New-Item -ItemType directory -Path $outputPackageDir
  }
  Get-ChildItem *.nuspec -Recurse | Foreach-Object {
    # chocolatey pack expects a package name argument only, quotes are necessary to inject the additional OutputDir argument
    exec { & $chocolatey pack """$($_.FullName)"" -OutputDir $(Resolve-Path $outputPackageDir)" }
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
  exec { & $chocolatey install seek-dsc -source $(Resolve-Path $outputPackageDir) }
}

task Uninstall {
  exec { & $chocolatey uninstall seek-dsc -source $(Resolve-Path $outputPackageDir) }
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
    exec { & $pester -Path $Path -TestName $TestName }
  }
  else {
    exec { & $pester -Path $Path }
  }
}