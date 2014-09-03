try
{
	$DSCResourcesRoot = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules"
	$DSCResourceTarget = Join-Path $env:chocolateyPackageFolder "lib"
	Get-ChildItem $DSCResourceTarget | foreach { Remove-Item "$DSCResourcesRoot\$_" -Recurse -Force }

	Write-ChocolateySuccess 'SEEK PowerShell DSC Resources'
} catch {
	Write-ChocolateyFailure 'SEEK PowerShell DSC Resources' $($_.Exception.Message)
	throw $_
}
