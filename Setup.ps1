$DSCResourcesTarget = Join-Path $PSScriptRoot "Modules"
$DSCResourcesRoot = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules"

Get-ChildItem $DSCResourcesTarget | foreach {cmd /c rmdir /S /Q "$DSCResourcesRoot/$_"; cmd /c mklink /j "$DSCResourcesRoot/$_" "$DSCResourcesTarget/$_"}
