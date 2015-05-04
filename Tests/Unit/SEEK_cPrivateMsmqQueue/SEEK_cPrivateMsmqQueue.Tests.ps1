Import-Module (Join-Path $PSScriptRoot "..\..\..\Modules\cMessageQueue\DSCResources\SEEK_cPrivateMsmqQueue\SEEK_cPrivateMsmqQueue.psm1")

InModuleScope "SEEK_cPrivateMsmqQueue" {
    $QueueDetails = @{
        Name = "MyQueue"
        Ensure = "Present"
        Transactional = $true
        UseJournalQueue = $false
        MaximumJournalSize = 1024
        Label = "private$\MyQueue"
    }

    Describe "Get-TargetResource" {
        Context "when queue is present" {
            Mock Test-QueueExists {return $true}
            Mock Get-QueueDetails {return $QueueDetails} -ParameterFilter {$Name -eq "MyQueue"}

            It "returns the queue state as a hashtable" {
                $Queue = Get-TargetResource -Name "MyQueue"
                $Queue.Name | Should Be "MyQueue"
                $Queue.Ensure | Should Be "Present"
                $Queue.Transactional | Should Be $true
                $queue.UseJournalQueue | Should Be $false
                $queue.MaximumJournalSize | Should Be 1024
                $queue.Label = "private$\MyQueue"
            }
        }

        Context "when queue is absent" {
            Mock Get-QueueDetails
            Mock Test-QueueExists {return $false}

            It "Get-TargetResource returns an absent queue hashtable" {
                $Queue = Get-TargetResource -Name "MyQueue"
                $Queue.Name | should be "MyQueue"
                $Queue.Ensure | should be "Absent"
            }
        }
    }

    Describe "Test-TargetResource" {
        Context "when the queue is in the desired state" {
            Mock Test-QueueExists {return $true}
            Mock Get-QueueDetails {return $QueueDetails} -ParameterFilter {$Name -eq "MyQueue"}

            It "returns true" {
                $result = Test-TargetResource `
                    -Name "MyQueue" `
                    -Transactional "true" `
                    -UseJournalQueue "false" `
                    -MaximumJournalSize "1024" `
                    -Label "private$\MyQueue"

                $result | Should Be $true
            }
        }

        Context "when the queue differs from the desired state" {
            Mock Test-QueueExists {return $true}
            Mock Get-QueueDetails {return $QueueDetails} -ParameterFilter {$Name -eq "MyQueue"}

            It "returns false if the Transactional flag is different" {

                Test-TargetResource -Name "MyQueue" -Transactional "false" | Should Be $false
            }

            It "returns false if the UseJournalQueue flag is different" {

                Test-TargetResource -Name "MyQueue" -UseJournalQueue "true" | Should Be $false
            }

            It "returns false if the MaximumJournalSize is different" {

                Test-TargetResource -Name "MyQueue" -MaximumJournalSize "2048" | Should Be $false
            }

            It "returns false if the Label is different" {

                Test-TargetResource -Name "MyQueue" -Label "MyLabel" | Should Be $false
            }
        }

        Context "when queue is absent" {
            Mock Get-QueueDetails
            Mock Test-QueueExists {return $false}

            It "Test-TargetResource returns false" {
                Test-TargetResource -Name "MyQueue" | Should Be $false
            }
        }
    }

    Describe "Set-TargetResource" {
        Mock New-Queue
        Mock Remove-Queue

        Context "when queue is absent" {
            Mock Test-QueueExists {return $false}

            It "creates a new queue" {
                Mock New-Queue {} -Verifiable -ParameterFilter {
                    $Name -eq "MyQueue" `
                    -and $Transactional -eq $true `
                    -and $UseJournalQueue -eq  $false `
                    -and $MaximumJournalSize -eq 1024 `
                    -and $Label -eq "private$\MyQueue"
                }
                Set-TargetResource -Name "MyQueue"
                Assert-VerifiableMocks
            }
        }

        Context "when queue is present" {
            Mock Test-QueueExists {return $true}

            It "recreates the queue when the state is changed" {
                Mock New-Queue {} -ParameterFilter {$Name -eq "MyQueue"}
                Set-TargetResource -Name "MyQueue" `
                    -Transactional "false" `
                    -UseJournalQueue "true" `
                    -MaximumJournalSize "2048" `
                    -Label "MyLabel"
                Assert-MockCalled Remove-Queue 1 {$Name -eq "MyQueue"}
                Assert-MockCalled New-Queue 1 {
                    $Name -eq "MyQueue" `
                    -and $Transactional -eq $false `
                    -and $UseJournalQueue -eq  $true `
                    -and $MaximumJournalSize -eq 2048 `
                    -and $Label -eq "MyLabel"
                }
            }
        }

        Context "when configuration specifies the queue should be absent" {
            Mock Test-QueueExists {return $true}

            It "removes the queue" {
                Set-TargetResource -Name "MyQueue" -Ensure "Absent"
                Assert-MockCalled Remove-Queue 1 {$Name -eq "MyQueue"}
            }
        }
    }
}
