properties {
	$pesterHome = ".\Packages\Pester.2.1.0\tools"
	$pester = "${pesterHome}\bin\pester.bat"
    $testOutput = ".\Test.xml" 
}

task default -depends TestAll

task TestAll -depends Clean, UnitTest, IntegrationTest, E2ETest

task UnitTest {
	Invoke-Tests -Path .\Tests\Unit
}

task IntegrationTest {
	Invoke-Tests -Path .\Tests\Integration
}

task E2ETest {
	Invoke-Tests -Path .\Tests\E2E
}

task Test {
	Invoke-Tests -Path $testPath -TestName $testName
}

task Clean {
	if (Test-Path $testOutput) {
		Remove-Item $testOutput
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