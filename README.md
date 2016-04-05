# THIS PROJECT IS NO LONGER MAINTAINED
# IT WILL BE REMOVED WITHIN THE NEXT 3 MONTHS

### Contact jbaker@seek.com.au if you have question/comments/etc
### Work is underway to backport most of this into the Microsoft Github repo https://github.com/PowerShell

# SEEK Ltd. PowerShell Desired State Configuration Resources

This project includes custom DSC resources used by SEEK Ltd.

[![Build status](https://ci.appveyor.com/api/projects/status/laj1i4wxmxj7nkc8)](https://ci.appveyor.com/project/SEEKJobs/dsc)


## Setup

After cloning this repository, it is necessary to perform a once-off setup. The setup will setup symlinks in the PowerShell Module path to the custom DSC resources.

### Why?

The PowerShell DSC configuration is applied by the Local Configuration Manager (LCM). The LCM runs as the SYSTEM user, so any custom resources must reside in the SYSTEM user's `$env:PSModulePath` (either `$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules` or `$env:ProgramFiles\WindowsPowerShell\Modules`)

### Pre-requisites

- Chocolatey

```
PS> iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
```

If you are behind a HTTP proxy you may need to run the following command before installing chocolatey.

```
PS> [net.webrequest]::defaultwebproxy.credentials = [net.credentialcache]::defaultcredentials
```

#### Runtime Dependencies

- [Windows Management Framework 4.0](http://www.microsoft.com/en-au/download/details.aspx?id=40855) required to provide PowerShell 4 and necessary cmdlets
- Your user must have local administrator privileges


### Installation

Simply install the chocolatey package (as administrator):

```
PS> choco install seek-dsc
```

You should now see some modules in the PowerShell Module path. For example:

```
PS> ls $env:ProgramFiles\WindowsPowerShell\Modules
```

## Creating Custom DSC Resources

Please see the Writing a Custom DSC Resource chapter in [The DSC book](http://powershell.org/wp/ebooks/).


## Development Environment

To get quick feedback you can put the DSC source code directly on the PSModulePath. The following task does this for you:

```
.\build.ps1 EnableDeveloperMode
```

To remove the DSC source from the PSModulePath, run the following task:

```
.\build.ps1 DisableDeveloperMode
```

## Testing

If you wish to contribute to the SEEK DSC resources, please ensure you run the tests before sending a pull request. Tests are run using [Pester](https://github.com/pester/Pester) (a BDD test framework for PowerShell). Pester tests can be found under the `Tests` directory.

### Test Dependencies

- [.Net Framework 4](http://www.microsoft.com/en-au/download/details.aspx?id=17718) required to run build


### Test suite:

The following command will run the full suite of tests:

```
.\build.ps1 TestAll
```

#### Unit tests:

Unit tests are the most important and test the DSC resource contract. Namely the `Get-TargetResource`, `Set-TargetResource` and `Test-TargetResource` functions. The unit tests should run in isolation and mock-out any interactions with external commands or the network.

NOTE: if cmdlets cannot be mocked directly, it is acceptable to partially mock the Script Under Test (SUT). This can be achieved by wrapping the cmdlet call in a function and simply mocking the wrapper function.

To run just the unit tests, use the following command:

```
.\build.ps1 UnitTest
```

#### Integration tests:

Itegration tests are not absolutely necessary. They are however useful to get some extra confidence that your wrapper functions interact with external commands correctly.

Run the integration tests using the following command:

```
.\build.ps1 IntegrationTest
```

#### E2E tests:

Each module should have one end-to-end test. This ensures that a DSC configuration can import and utilise the custom resource. There is no other way to test that the resource schema matches the `Get-TargetResource` and `Set-targetResource` parameters. E2E tests are expensive so do not use E2E tests for exhaustive scenarios, they should simply test a single happy-days scenario.

To run the E2E tests, run the following command:

```
.\build.ps1 E2ETest
```

