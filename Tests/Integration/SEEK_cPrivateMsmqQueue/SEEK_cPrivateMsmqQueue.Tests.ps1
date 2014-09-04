$module = Join-Path $PSScriptRoot "..\..\..\Modules\SEEK - Modules\cMessageQueue\DSCResources\SEEK_cPrivateMsmqQueue\SEEK_cPrivateMsmqQueue.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Add-Type -AssemblyName "System.Messaging, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a"

$TestQueuePath = ".\private$\Test"

function Remove-TestQueue
{
    if ([System.Messaging.MessageQueue]::Exists($TestQueuePath))
    {
        [System.Messaging.MessageQueue]::Delete($TestQueuePath)
    }
}

function New-TestQueue
{
    Remove-TestQueue
    $Queue = [System.Messaging.MessageQueue]::Create($TestQueuePath, $true)
    $Queue.UseJournalQueue = $true
	$Queue.MaximumJournalSize = 2048
	$Queue.Label = "TestLabel"
}

Describe "Get-QueueDetails" {
    Context "when queue exists" {
        New-TestQueue

        It "returns details as a hash" {
            $Details = Get-QueueDetails -Name "Test"
            $Details.Name | Should Be "Test"
            $Details.Ensure | Should Be "Present"
            $Details.Transactional | Should Be $true
            $Details.UseJournalQueue | Should Be $true
		    $Details.MaximumJournalSize | Should Be 2048
		    $Details.Label| Should Be "TestLabel"
        }

        Remove-TestQueue
    }
}

Describe "Test-QueueExists" {
    Context "when queue exists" {
        New-TestQueue

        It "returns true" {
            Test-QueueExists -Name "Test" | Should Be $true
        }
    }

    Context "when queue is absent" {
        Remove-TestQueue

        It "returns false" {
             Test-QueueExists -Name "Test" | Should Be $false
        }
    }

    Remove-TestQueue
}

Describe "Remove-Queue" {
    Context "when queue exists" {
        New-TestQueue

        It "removes the queue" {
            Remove-Queue -Name "Test"
            [System.Messaging.MessageQueue]::Exists($TestQueuePath) | Should Be $false
        }
    }

    Context "when queue is absent" {
        Remove-TestQueue

        It "does nothing" {
             Remove-Queue -Name "Test"
             [System.Messaging.MessageQueue]::Exists($TestQueuePath) | Should Be $false
        }
    }

    Remove-TestQueue
}

Describe "New-Queue" {
    Context "when queue exists" {
        New-TestQueue

        It "throws an exception" {
            { New-Queue -Name "Test" } | Should Throw
        }
    }

    Context "when queue is absent" {
        Remove-TestQueue

        It "creates a new queue" {
             New-Queue -Name "Test" -Transactional $true -UseJournalQueue $false -MaximumJournalSize 1024 -Label "Test"
             [System.Messaging.MessageQueue]::Exists($TestQueuePath) | Should Be $true
        }
    }

    Remove-TestQueue
}
