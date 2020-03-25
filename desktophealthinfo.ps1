function Get-DesktopHealthInfo{
    param(
        [parameter(mandatory=$true)]
        $hvServer
    )
    
   $queryService = New-Object VMware.Hv.QueryServiceService
   $defn = New-Object VMware.Hv.QueryDefinition
   $defn.queryEntityType = 'DesktopHealthInfo'
   
    $queryService.QueryService_Query($hvserver.ExtensionData,$defn)
}


function Get-Farms{
    param(
        [parameter(mandatory=$true)]
        $hvServer
    )
    
   $queryService = New-Object VMware.Hv.QueryServiceService
   $defn = New-Object VMware.Hv.QueryDefinition
   $defn.queryEntityType = 'FarmSummaryView'
   
    $queryService.QueryService_Query($hvserver.ExtensionData,$defn)
}