function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [String[]]$Services = @("AppFabricWorkflowManagementService", "AppFabricEventCollectionService"),
        [Int]$Index = 0
    )

    $serviceStatuses = $Services | ForEach-Object {
        Get-Service $_ | Select-Object -ExpandProperty Status
    }
    if ($serviceStatuses.Contains("Stopped")) {
        return @{
            Services = $Services
            Ensure = "Absent"
        }
    }

    return @{
        Services = $Services
        Ensure = "Present"
    }
}


function Set-TargetResource {
    [CmdletBinding()]
    param (
        [String[]]$Services = @("AppFabricWorkflowManagementService", "AppFabricEventCollectionService"),

        [Int]$Index = 0,

        [ValidateSet("Present","Absent")]
        [String]$Ensure = "Present"
    )

    if ($Ensure -eq "Present") {
        $Services | ForEach-Object { Start-Service $_ }
    }
    else {
        $Services | ForEach-Object { Stop-Service $_ }
    }
}


function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [String[]]$Services = @("AppFabricWorkflowManagementService", "AppFabricEventCollectionService"),

        [Int]$Index = 0,

        [ValidateSet("Present","Absent")]
        [String]$Ensure = "Present"
    )

    $resource = Get-TargetResource -Services $Services

    if($resource.Ensure -eq $Ensure)
    {
        return $true
    }

    return $false
}

Export-ModuleMember -Function *-TargetResource
