trap
{
  # this script is called via -File in the powershell params which will not always return a valid exit code on exception
  # catch any exception and force the exit code.
  write-output $_
  exit 1
}

$nugetHome = ".\.nuget\NuGet.CommandLine.2.8.2\tools"
$nuget = "${nugetHome}\NuGet.exe"
& $nuget install .\.nuget\packages.config -OutputDirectory .\Packages -NonInteractive
Import-Module (Join-Path $PSScriptRoot "Packages\psake.4.3.2\tools\psake.psm1")
Invoke-Psake @args