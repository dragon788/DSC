$module = Join-Path $PSScriptRoot "..\..\..\Modules\cDatabase\DSCResources\SEEK_cSQLLogin\SEEK_cSQLLogin.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Describe "Set-TargetResource" {
    Context "when ensure is present" {
        It "should create a new SQL login" {
            $create =
            {
                param($Password)
                $this.Result =  $Password -eq "Passy"
            }

            $loginObject =  New-Object -TypeName PSObject
            $loginObject | Add-Member -NotePropertyName LoginType -NotePropertyValue ""
            $loginObject | Add-Member -NotePropertyName PasswordPolicyEnforced -NotePropertyValue $true
            $loginObject | Add-Member -NotePropertyName PasswordExpirationEnabled -NotePropertyValue $true
            $loginObject | Add-Member -NotePropertyName Result -NotePropertyValue $false
            $loginObject | Add-Member -MemberType ScriptMethod -Name Create -Value $create

            Mock new-object { $loginObject }

            Set-TargetResource -User "Matt" -Password "Passy"

            $loginObject.LoginType | Should Be "SqlLogin"
            $loginObject.PasswordPolicyEnforced | Should Be $false
            $loginObject.PasswordExpirationEnabled | Should Be  $false
            $loginObject.Result | Should be $true
        }
    }

    Context "when ensure is absent" {
        It "should drop the SQL login" {
            $drop = { $this.Result = $true }

            $dropObject = New-Object -TypeName PSObject
            $dropObject | Add-Member -MemberType ScriptMethod -Name Drop -Value $drop
            $dropObject | Add-Member -NotePropertyName Result -NotePropertyValue $false

            $item = {
                $dropObject
            }

            $smoLoginsObject = New-Object -TypeName PSObject
            $smoLoginsObject | Add-Member -MemberType ScriptMethod -Name Item -Value $item

            Mock New-Object { @{logins = $smoLoginsObject;  } }

            Set-TargetResource -User "Matt" -Password "Passy" -Ensure "Absent"

            $dropObject.Result | Should be $true
        }
    }
}

Describe "Get-TargetResource" {
    Context "when the login exists" {
        It "is returned" {
            $itemMethod =
            {
                @{
                    Name = "Matt";
                    Parent = @{Name = "D12345"};
                }
            }

            $smoLoginsObject = New-Object -TypeName PSObject
            $smoLoginsObject | Add-Member -MemberType ScriptMethod -Name Item -Value $itemMethod

            Mock New-Object { @{logins = $smoLoginsObject } }

            $result = Get-TargetResource -User "Matt" -Password "Passy" -Server "(local)"

            $result.Ensure | Should Be "Present"
            $result.User | Should Be "Matt"
            $result.Server | Should Be "D12345"
            $result.Password | Should Be $null
        }
    }

    Context "when the login exists" {
        It "is not returned" {
            $smoLoginsObject = New-Object -TypeName PSObject
            $smoLoginsObject | Add-Member -MemberType ScriptMethod -Name Item -Value { $null }

            Mock New-Object { @{logins = $smoLoginsObject } }

            $result = Get-TargetResource -User "Matt" -Password "Passy" -Server "(local)"

            $result.Ensure | Should Be "Absent"
            $result.User | Should Be $null
            $result.Server | Should Be $null
            $result.Password | Should Be $null
        }
    }
}

Describe "Test-TargetResource" {
    Context "when the login exists" {
        $itemMethod =
        {
            @{
                Name = "Matt";
                Parent = @{Name = "D12345"};
            }
        }

        $smoLoginsObject = New-Object -TypeName PSObject
        $smoLoginsObject | Add-Member -MemberType ScriptMethod -Name Item -Value $itemMethod
        Mock New-Object { @{logins = $smoLoginsObject } }

        It "should return true, when ensure is present" {
            $result = Test-TargetResource -User "Matt" -Password "Passy" -Server "(local)"
            $result | Should Be $true
        }

        It "should return false, when ensure is absent" {
            $result = Test-TargetResource -User "Matt" -Password "Passy" -Server "(local)" -Ensure  "Absent"
            $result | Should Be $false
        }
    }

    Context "when the login does not exist" {
        $smoLoginsObject = New-Object -TypeName PSObject
        $smoLoginsObject | Add-Member -MemberType ScriptMethod -Name Item -Value { $null }

        Mock New-Object { @{logins = $smoLoginsObject } }

        It "should return false, when ensure is present" {
            $result = Test-TargetResource -User "Matt" -Password "Passy" -Server "(local)"
            $result | Should Be $false
        }

        It "should return true, when ensure is absent" {
            $result = Test-TargetResource -User "Matt" -Password "Passy" -Server "(local)" -Ensure "Absent"
            $result | Should Be $true
        }
    }
}
