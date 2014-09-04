$module = Join-Path $PSScriptRoot "..\..\..\Modules\SEEK - Modules\cMessageQueue\DSCResources\SEEK_cPrivateMsmqQueuePermissions\SEEK_cPrivateMsmqQueuePermissions.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

$MockQueue = New-Object PSObject
$MockQueue | Add-Member QueueName "private$\MyQueue"

Describe "Get-TargetResource" {
    Context "given it is not possible to retrieve current queue permissions" {
        It "returns dummy details as a hashtable" {
            $QueuePermissions = Get-TargetResource -Name "MyQueuePermissions"
            $QueuePermissions.Name | Should Be "MyQueuePermissions"
        }
    }
}

Describe "Test-TargetResource" {
    Context "given it is not possible to retrieve current queue permissions" {
        It "always returns false" {
            Test-TargetResource -Name "MyQueuePermissions" -QueueNames @("MyQueue") | Should Be $false
        }
    }
}

Describe "Set-TargetResource" {
    Mock Set-Permissions
    Mock Reset-Permissions { process { Write-Output $InputObject } }
    Mock Get-PrivateQueues { New-Object PSObject | Add-Member Queue $MockQueue -PassThru }

    Context "when configuration specifies the queue should be present" {
        It "always recreates permissions" {
            Set-TargetResource -Name "MyQueuePermissions" -QueueNames @("MyQueue") -AdminUsers @("Joe") -Ensure "Present"
            Assert-MockCalled Reset-Permissions -Exactly 1 {$InputObject.Queue.QueueName -eq $MockQueue.QueueName}
            Assert-MockCalled Set-Permissions -Exactly 1 {$InputObject.Queue.QueueName -eq $MockQueue.QueueName}
        }
    }

    Context "when configuration specifies the queue should be absent" {
        It "resets the permissions on the queue" {
            Set-TargetResource -Name "MyQueuePermissions" -QueueNames @("MyQueue") -AdminUsers @("Joe") -Ensure "Absent"
            Assert-MockCalled Reset-Permissions -Exactly 1
        }

        It "does not apply new permissions on the queue" {
            Set-TargetResource -Name "MyQueuePermissions" -QueueNames @("MyQueue") -AdminUsers @("Joe") -Ensure "Absent"
            Assert-MockCalled Set-Permissions 0
        }
    }

    Context "when permissions are applied to multiple queues" {
        $AnotherMockQueue = New-Object PSObject
        $AnotherMockQueue | Add-Member QueueName "private$\AnotherQueue"
        Mock Get-PrivateQueues {
            New-Object PSObject | Add-Member Queue $MockQueue -PassThru
            New-Object PSObject | Add-Member Queue $AnotherMockQueue -PassThru
        }

        It "recreates permissions on each queue" {
            Set-TargetResource -Name "MyQueuePermissions" -QueueNames @("MyQueue","AnotherQueue") -AdminUsers @("Joe")
            Assert-MockCalled Reset-Permissions -Exactly 2
            Assert-MockCalled Set-Permissions -Exactly 2
        }
    }

    Context "when queues do not match" {
        $OtherMockQueue = New-Object PSObject
        $OtherMockQueue | Add-Member QueueName "private$\OtherQueue"
        Mock Get-PrivateQueues {
            New-Object PSObject | Add-Member Queue $OtherMockQueue -PassThru
            New-Object PSObject | Add-Member Queue $MockQueue -PassThru
        }

        It "does not alter the permissions of non-matching queues" {
            Set-TargetResource -Name "MyQueuePermissions" -QueueNames @("MyQueue") -AdminUsers @("Joe")
            Assert-MockCalled Reset-Permissions -Exactly 1 {$InputObject.Queue.QueueName -eq $MockQueue.QueueName}
            Assert-MockCalled Set-Permissions -Exactly 1 {$InputObject.Queue.QueueName -eq $MockQueue.QueueName}
        }
    }
}
