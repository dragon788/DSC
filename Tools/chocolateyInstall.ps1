try
{
	$DSCResourcesRoot = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules"
	$DSCResourceTarget = Join-Path $env:chocolateyPackageFolder "lib"
	Get-ChildItem $DSCResourceTarget | Foreach-Object {
		if (Test-Path "$DSCResourcesRoot\$_") {
			cmd /c rmdir "$DSCResourcesRoot\$_"
		}
		cmd /c mklink /j "$DSCResourcesRoot\$_" "$DSCResourceTarget\$_"
		Get-ChildItem -Path "$DSCResourcesRoot\$_" -File -Recurse | Unblock-File
	}

	Write-ChocolateySuccess 'SEEK PowerShell DSC Resources'
} catch {
	Write-ChocolateyFailure 'SEEK PowerShell DSC Resources' $($_.Exception.Message)
	$host.SetShouldExit(1)
	throw $_
}
