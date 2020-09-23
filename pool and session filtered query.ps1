#This script demo's how to retrieve sessions from a specific pool
import-module vmware.powercli

function Get-ViewAPIService {
    param(
      [Parameter(Mandatory = $false)]
      $HvServer
    )
    if ($null -ne $hvServer) {
      if ($hvServer.GetType().name -ne 'ViewServerImpl') {
        $type = $hvServer.GetType().name
        Write-Error "Expected hvServer type is ViewServerImpl, but received: [$type]"
        return $null
      }
      elseif ($hvServer.IsConnected) {
        return $hvServer.ExtensionData
      }
    } elseif ($global:DefaultHVServers.Length -gt 0) {
       $hvServer = $global:DefaultHVServers[0]
       return $hvServer.ExtensionData
    }
    return $null
  }

function Get-HVDesktopPool
{
    param(
        [parameter(mandatory=$true)]
        $hvServer,
        $PoolName
    )
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'DesktopSummaryView'
    if($null -ne $PoolName){
        $filter = new-object VMware.Hv.QueryFilterContains
        $filter.MemberName= "desktopSummaryData.name"
        $filter.value = $DesktopPool
        $query.filter = $filter
    }
    $services = Get-ViewAPIService -hvServer $hvServer
    $query_service_helper.QueryService_Query($services, $query).results
}
function Get-HVSessionLocalSummaryView{
    param(
        [parameter(mandatory=$true)]
        $hvServer,
        [VMware.Hv.DesktopId]$DesktopPoolID
    )
    $Results=@()
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'SessionLocalSummaryView'
    if($null -ne $DesktopPoolID){
        write-warning "$($DesktopPoolID)"
        $filter = new-object VMware.Hv.QueryFilterEquals
        $filter.MemberName= "referenceData.desktop"
        $filter.value = $DesktopPoolID
        $query.filter = $filter
    }
    $services = Get-ViewAPIService -hvServer $hvServer
    $queryResponse = $query_service_helper.QueryService_Create($services, $query)
    $results+=$queryResponse.Results
    if($queryResponse.RemainingCount -gt 0){
        Write-Verbose "Found further results to retrieve"
        $remaining=$queryResponse.RemainingCount
        do{
            
            $latestResponse = $query_service_helper.QueryService_GetNext($services,$queryResponse.Id)
            $results+= $latestResponse.Results
            Write-Verbose "Pulled an additional $($latestResponse.Results.Count) item(s)"
            $remaining = $latestResponse.RemainingCount
        }while($remaining -gt 0)
    }

    $query_service_helper.QueryService_Delete($services,$queryResponse.Id)
    $results
}


$hv = Connect-HVServer pod1hcon1.lab.local
$pool = Get-HVDesktopPool -poolname "2016_dev" -hvServer $hv
$sessions = Get-HVSessionLocalSummaryView -hvserver $hv -DesktopPool $pool.id