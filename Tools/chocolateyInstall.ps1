try
{
	$DSCResourcesRoot = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules"
	$DSCResourceTarget = Join-Path $env:chocolateyPackageFolder "lib"
	Get-ChildItem $DSCResourceTarget | Foreach-Object {
		if (Test-Path "$DSCResourcesRoot\$_") {
			Remove-Item "$DSCResourcesRoot\$_" -Recurse -Force
		}
		cmd /c mklink /j "$DSCResourcesRoot\$_" "$DSCResourceTarget\$_"
	}

	Write-ChocolateySuccess 'SEEK PowerShell DSC Resources'
} catch {
	Write-ChocolateyFailure 'SEEK PowerShell DSC Resources' $($_.Exception.Message)
	throw $_
}
