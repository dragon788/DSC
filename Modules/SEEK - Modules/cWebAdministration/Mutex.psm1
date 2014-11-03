function Synchronized
{
    [CmdletBinding()]
    param
    (
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[^\\]?")]
        [parameter(Mandatory = $true)]
        [string] $Name,

        [parameter(Mandatory = $false)]
        [int] $MillisecondsTimeout = 5000,

        [parameter(Mandatory = $false)]
        [boolean] $InitiallyOwned = $false,

        [parameter(Mandatory = $false)]
        [Object[]] $ArgumentList = @(),

        [parameter(Mandatory = $false)]
        [ValidateSet("Global","Local","Session")]
        [Object[]] $Scope = "Global",

        [parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    $mutex = New-Object System.Threading.Mutex($InitiallyOwned, "${Scope}\${Name}")
    
    if ($mutex.WaitOne($MillisecondsTimeout)) {
        try {
            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        }
        finally {
            $mutex.ReleaseMutex()
        }
    }
    else { throw "Cannot aquire mutex: $Name"}
}