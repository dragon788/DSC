$module = Join-Path $PSScriptRoot "..\..\Modules\SEEK - Modules\cWebAdministration\Mutex.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Synchronized script block" {

    Context "when name parameter contains backslashes" {
        It "fails validation" {
            { Synchronized -Name "C:\foo.txt" -ScriptBlock {} } | Should Throw
        }
    }

 	Context "when two threads try run idenically named blocks concurrently" {
        It "is thread-safe" {
            $filePath = (Join-Path $TestDrive "mutex.lock")
            Write-Host "lock file: $filePath"
            
            # lock on a resource within a synchronized block
            $lockJob = Start-Job -ArgumentList $module, $filePath {
                Write-Host "Importing module: $($args[0])"
                Import-Module $args[0]
                Synchronized -Name "TestMutex" -ArgumentList $args[1] -ScriptBlock {
                    Write-Host "creating lock file: $($args[0])"
                    New-Item $args[0] -type file
                    Write-Host "opening lock file"
                    $stream = (Get-Item $args[0]).OpenWrite()
                    Write-Host "sleeping"
                    Start-Sleep -m 5000
                    Write-Host "closing lock file"
                    $stream.close()
                }
            }

            # wait for background job to start
            Write-Host "waiting for lock file"
            do {
                Start-Sleep -m 1000
                $lockJob | Receive-Job
            } while (-not (Test-Path $filePath))
            Write-Host "found lock file"
            
            # try and access the locked resource within a synchronized block
            {
                Synchronized -Name "TestMutex" -ArgumentList $filePath -ScriptBlock {
                    Write-Host "trying to open lock file: $($args[0])"
                    $stream = (Get-Item $args[0]).OpenWrite()
                    Write-Host "closing lock file"
                    $stream.close()
                }
            } | Should Not Throw

            # wait for the background job to finish
            Write-Host "cleaning up..."
            $lockJob | Wait-Job | Receive-Job
        }
    }
}