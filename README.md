# SEEK Ltd. PowerShell Desired State Configuration Resources

This project includes custom DSC resources used by SEEK Ltd.

## Setup

After cloning this repository, it is necessary to perform a once-off setup. The setup will setup symlinks in the PowerShell Module path to the custom DSC resources.

### Why?

The PowerShell DSC configuration is applied by the Local Configuration Manager (LCM). The LCM runs as the SYSTEM user, so any custom resources must reside in the SYSTEM user's `$env:PSModulePath` (either `$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules` or `$env:ProgramFiles\WindowsPowerShell\Modules`)

### Pre-requisites

- Git client
- This project must be cloned to the local machine

```
PS> git clone https://github.com/SEEK-Jobs/DSC.git
```

#### Runtime Dependencies

- [Windows Management Framework 4.0](http://www.microsoft.com/en-au/download/details.aspx?id=40855) required to provide PowerShell 4 and necessary cmdlets
- Your user must have local administrator privileges


### Installation

Simply run the setup script from the project (as administrator):

```
PS> cd DSC
PS> .\Setup.ps1
```

You should now see some modules in the PowerShell Module path. For example:

```
PS> ls $env:ProgramFiles\WindowsPowerShell\modules


    Directory: C:\Program Files\WindowsPowerShell\Modules


Mode                LastWriteTime     Length Name
----                -------------     ------ ----
d----        26/05/2014   3:57 PM            SEEK - Modules
```

## Creating Custom DSC Resources

Please see the Writing a Custom DSC Resource chapter in [The DSC book](http://powershell.org/wp/ebooks/).

## Testing

If you wish to contribute to the SEEK DSC resources, please ensure you run the tests before sending a pull request. Tests are run using [Pester](https://github.com/pester/Pester) (a BDD test framework for PowerShell). Pester tests can be found under the `Tests` directory.

### Test Dependencies

- [.Net Framework 4](http://www.microsoft.com/en-au/download/details.aspx?id=17718) required to run build
- [Pester](https://github.com/pester/Pester) required to run tests


#### Installing Pester

The Pester project can be downloaded from GitHub as a [ZIP](https://github.com/pester/Pester/archive/master.zip), cloned using [Git](https://github.com/pester/Pester.git) or installed as a [Chocolatey package](http://chocolatey.org/packages/poshgit). By default, the build expects Pester to be installed using Chocolatey. If you have installed pester manually, you can set the `PESTER_HOME` environment variable with the install location.

##### Installing Pester Chocolatey Package

- Install Chocolatey
```
PS> Set-ExecutionPolicy RemoteSigned
PS> iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
```
- Install Pester package
```
PS> choco install .\packages.config
```

##### Installing Pester in a custom location

Assuming you want to install Pester into a custom location (e.g. `D:\Tools\Pester`)

- Clone the Git repository:
```
PS> mkdir D:\Tools
PS> cd D:\Tools
PS> git clone https://github.com/pester/Pester.git
```
- Set the `PESTER_HOME` user-level environment variable:
```
PS> [Environment]::SetEnvironmentVariable("PESTER_HOME", "D:\Tools\Pester", "User")
```
- Close the current PowerShell console

### Test suite:

The following command will run the full suite of tests:

```
.\build.bat /t:Test
```

#### Unit tests:

Unit tests are the most important and test the DSC resource contract. Namely the `Get-TargetResource`, `Set-TargetResource` and `Test-TargetResource` functions. The unit tests should run in isolation and mock-out any interactions with external commands or the network.

NOTE: if cmdlets cannot be mocked directly, it is acceptable to partially mock the Script Under Test (SUT). This can be achieved by wrapping the cmdlet call in a function and simply mocking the wrapper function.

To run just the unit tests, use the following command:

```
.\build.bat /t:UnitTest
```

#### Integration tests:

Itegration tests are not absolutely necessary. They are however useful to get some extra confidence that your wrapper functions interact with external commands correctly.

Run the integration tests using the following command:

```
.\build.bat /t:\IntegrationTest
```

#### E2E tests:

Each module should have one end-to-end test. This ensures that a DSC configuration can import and utilise the custom resource. There is no other way to test that the resource schema matches the `Get-TargetResource` and `Set-targetResource` parameters. E2E tests are expensive so do not use E2E tests for exhaustive scenarios, they should simply test a single happy-days scenario.

To run the E2E tests, run the following command:

```
.\build.bat /t:E2ETest
```
