# this script demo's how to report on app launches via the eventsdatabase

import-module vmware.powercli

function Get-EventSummaryView{
    param(
        [parameter(mandatory=$true)]
        $hvServer
    )
    $Results=@()
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'EventSummaryView'
    $services = Get-ViewAPIService -hvServer $hvServer
    
    $AppLaunchFilter = New-Object VMware.Hv.QueryFilterEquals
    $AppLaunchFilter.memberName = 'data.eventType'
    $AppLaunchFilter.value = 'BROKER_APPLICATION_REQUEST'

    
    $date=Get-Date -Hour 0 -Minute 00 -Second 00

    $DateFilter = new-object VMware.Hv.QueryFilterBetween
    $DateFilter.FromValue = $date.AddDays(-7)
    $DateFilter.ToValue = $date
    $datefilter.MemberName= 'data.time'
    $query.Filter = $AppLaunchFilter
    
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


$creds = Get-Credential
$serverAddress = "pod1hcon1.lab.local" # Connection Server address
$hvServer = Connect-HVServer -Server $serverAddress -Credential $creds
$logevents = Get-EventSummaryView $hvserver
$logevents | select-object @{Name="User"; Expression={$_.namesdata.userdisplayname}},@{Name="AppName"; Expression={$_.namesdata.applicationName}}
