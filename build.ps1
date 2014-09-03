$nugetHome = ".\Packages\NuGet.CommandLine.2.8.2\tools"
$nuget = "${nugetHome}\NuGet.exe"
& $nuget install .\Packages\packages.config -OutputDirectory .\Packages -NonInteractive
Import-Module (Join-Path $PSScriptRoot "Packages\psake.4.3.2\tools\psake.psm1")
Invoke-Psake ($args -join ' ')