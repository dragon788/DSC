Import-Module(Join-Path $PSScriptRoot "..\..\Modules\cWebAdministration\Mutex.psm1")

InModuleScope "Mutex" {
    Describe "Synchronized script block" {

        Context "when name parameter contains backslashes" {
            It "fails validation" {
                { Synchronized -Name "C:\foo.txt" -ScriptBlock {} } | Should Throw
            }
        }

        Context "when two threads try run idenically named blocks concurrently" {
            It "is thread-safe" {
                $filePath = (Join-Path $TestDrive "mutex.lock")
                $module = Join-Path $PSScriptRoot "..\..\Modules\cWebAdministration\Mutex.psm1"

                # lock on a resource within a synchronized block
                $lockJob = Start-Job -ArgumentList $module, $filePath {
                    Import-Module $args[0]
                    Synchronized -Name "TestMutex" -ArgumentList $args[1] -ScriptBlock {
                        New-Item $args[0] -type file
                        $stream = (Get-Item $args[0]).OpenWrite()
                        Start-Sleep -m 4000
                        $stream.close()
                    }
                }

                # wait for background job to start
                do {
                    Start-Sleep -m 1000
                    $lockJob | Receive-Job
                } while (-not (Test-Path $filePath))

                # try and access the locked resource within a synchronized block
                {
                    Synchronized -Name "TestMutex" -ArgumentList $filePath -ScriptBlock {
                        $stream = (Get-Item $args[0]).OpenWrite()
                        $stream.close()
                    }
                } | Should Not Throw

                # wait for the background job to finish
                $lockJob | Wait-Job | Receive-Job
            }
        }
    }
}
