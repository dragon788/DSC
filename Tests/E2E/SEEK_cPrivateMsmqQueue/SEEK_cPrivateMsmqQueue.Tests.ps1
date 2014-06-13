Configuration TestConfiguration
{
    Import-DscResource -Module cMessageQueue

    Node 'localhost'
    {
        cPrivateMsmqQueuePermissions TestQueuePermissions
        {
            Name = "Test"
            QueueNames = @("Test1","Test2")
            Ensure = "Present"
            AdminUsers = @("SEEK\IT Development Team")
            ReadUsers = @("SEEK\svc_developer_iis")
            WriteUsers = @("Everyone")
            DependsOn = @("[cPrivateMsmqQueue]Test1Queue", "[cPrivateMsmqQueue]Test2Queue")
        }

        cPrivateMsmqQueue Test1Queue
        {
            Name = "Test1"
            Ensure = "Present"
            Transactional = "True"
        }

        cPrivateMsmqQueue Test2Queue
        {
            Name = "Test2"
            Ensure = "Present"
            Transactional = "True"
        }

    }
}

Add-Type -AssemblyName "System.Messaging, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a"

function Remove-TestQueue($TestQueuePath)
{
    if ([System.Messaging.MessageQueue]::Exists($TestQueuePath))
    {
        [System.Messaging.MessageQueue]::Delete($TestQueuePath)
    }
}

Describe "PrivateMsmqQueue and PrivateMsmqQueuePermissions DSC Resource" {
    Remove-TestQueue ".\private$\Test1"
    Remove-TestQueue ".\private$\Test2"

    It "creates new queues with custom permissions" {
        TestConfiguration -OutputPath .\tmp
        Start-DscConfiguration -Wait -Verbose -Path .\tmp
        [System.Messaging.MessageQueue]::Exists(".\private$\Test1") | Should Be $true
        [System.Messaging.MessageQueue]::Exists(".\private$\Test2") | Should Be $true
    }

    It "gives the current user permissions to delete the queues" {
        { Remove-TestQueue ".\private$\Test1" } | Should Not Throw
        { Remove-TestQueue ".\private$\Test2" } | Should Not Throw
    }

    Remove-Item -Recurse -Force .\tmp -ErrorAction Ignore  | Out-Null
    Remove-TestQueue ".\private$\Test1"
    Remove-TestQueue ".\private$\Test2"
}
