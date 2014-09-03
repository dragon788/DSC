function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Path
    )

    $sharedDirectory = Get-WmiObject -Class Win32_Share | Where-Object -Property Path -eq $Path
    $ensure = if ($sharedDirectory -eq $null) { "Absent" } else { "Present" }

    @{ Ensure = $ensure; SharedDirectory = $sharedDirectory }
}

function Test-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [System.String]
        $Path,

        [System.String]
        $Description,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    (Get-TargetResource -Path $Path).Ensure -eq "Present"
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [System.String]
        $Path,

        [parameter(Mandatory)]
        [System.String]
        $Description,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure  = "Present"
    )

    $pathExists = Test-Path $Path

    switch ($Ensure)
    {
        "Present" {
            if (!$pathExists) { New-Item -Path $Path -Type "Directory" }
            (Get-WmiObject Win32_Share -List).Create($path, $description, 0)
        }

        "Absent" {
            if ($pathExists) { Remove-Item -Path $Path }
        }
    }
}

Export-ModuleMember -Function *-TargetResource
