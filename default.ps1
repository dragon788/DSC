properties {
	$pesterHome = ".\Packages\Pester.2.1.0\tools"
	$pester = "${pesterHome}\bin\pester.bat"
	$chocolateyHome = ".\Packages\chocolatey.0.9.8.27\tools\chocolateyInstall"
	$chocolatey = "${chocolateyHome}\chocolatey.cmd"
    $testOutput = ".\Test.xml"
    $outputDir = ".\Output"
    $outputPackageDir = $(Resolve-Path "${outputDir}\Packages")
}

task default -depends Clean, UnitTest, IntegrationTest

task Package -depends UnitTest, IntegrationTest {
	if (-not (Test-Path $outputPackageDir)) {
		New-Item -ItemType directory -Path $outputPackageDir
	}
	Get-ChildItem *.nuspec -Recurse | Foreach-Object {
		exec { & $chocolatey pack "$($_.FullName) -OutputDir $outputPackageDir" }
	}
}

task Install -depends Package {
	$packageNames = (Get-ChildItem .\Modules | ForEach-Object { $_.Name }) -join ' '
	exec { & $chocolatey install cHardDisk cMessageQueue cNetworking cNServiceBus cSoftware cWebAdministration -source $outputPackageDir }
}

task Uninstall {
	$packageNames = (Get-ChildItem .\Modules | ForEach-Object { $_.Name }) -join ' '
	exec { & $chocolatey uninstall cHardDisk cMessageQueue cNetworking cNServiceBus cSoftware cWebAdministration }
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