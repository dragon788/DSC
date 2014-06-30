function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ServiceName
    )


    $result = @{
        ServiceName = $ServiceName
        Ensure = "Present"
        Configuration = $null
        ApplicationRoot = $null
        DisplayName = $null
        Description = $null
        DependsOn = $null
    }

    return $result
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ServiceName,

        [ValidateSet("Present", "Absent")]
        [String]$Ensure = "Present",

        [ValidateSet("true", "false")]
        [String]$StartManually = "false",

        [Parameter(Mandatory)]
        [ValidateSet("Debug", "Release")]
        [String]$Configuration = "Release",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ApplicationRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$DisplayName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Description = $DisplayName,

        [String]$DependsOn
    )

    $args = @("/install",
        "/serviceName:${ServiceName}",
        "/displayName:${DisplayName}",
        "/description:${Description}")

    if ($StartManually) { $args += "/startManually" }
    if ($DependsOn) { $args += "/dependsOn:${DependsOn}" }

    Start-Process "${ApplicationRoot}\bin\${Configuration}\nservicebus.host.exe" `
        -ArgumentList $args `
        -Wait
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ServiceName,

        [ValidateSet("Present", "Absent")]
        [String]$Ensure = "Present",

        [Parameter(Mandatory)]
        [ValidateSet("Debug", "Release")]
        [String]$Configuration = "Release",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ApplicationRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$DisplayName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Description,

        [String]$DependsOn
    )

    return $false
}


#  FUNCTIONS TO BE EXPORTED
Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource
