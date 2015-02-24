# build requires IIS
Install-WindowsFeature Web-Server

# install packages required for build
[Environment]::SetEnvironmentVariable("PATH", `
  "${PSScriptRoot}\.nuget\NuGet.CommandLine.2.8.2\tools;" + $env:PATH, "Process")
NuGet.exe install ${PSScriptRoot}\.nuget\packages.config -ExcludeVersion `
  -OutputDirectory ${PSScriptRoot}\Packages -NonInteractive
if (-not $?) { exit 1 }

# package post-install: add installed packages to path
[Environment]::SetEnvironmentVariable("PATH", `
  "${PSScriptRoot}\Packages\chocolatey\tools\chocolateyInstall;" `
    + "${PSScriptRoot}\Packages\pester\tools\bin;" `
    + $env:PATH, "Process")

# run psake
Import-Module (Join-Path $PSScriptRoot "Packages\psake\tools\psake.psm1")
Invoke-Psake @args
if (-not $psake.build_success) { exit 1 }
