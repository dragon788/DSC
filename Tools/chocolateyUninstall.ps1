try
{
	$DSCResourcesRoot = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules"
	$DSCResourceTarget = Join-Path $env:chocolateyPackageFolder "lib"
	Get-ChildItem $DSCResourceTarget | Foreach-Object { cmd /c rmdir "$DSCResourcesRoot\$_" }

	Write-ChocolateySuccess 'SEEK PowerShell DSC Resources'
} catch {
	Write-ChocolateyFailure 'SEEK PowerShell DSC Resources' $($_.Exception.Message)
	throw $_
}
