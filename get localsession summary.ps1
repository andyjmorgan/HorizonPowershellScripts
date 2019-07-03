#This script demo's how to pull a local session summary from the query service

import-module vmware.powercli

function Get-SessionLocalSummaryView{
    param(
        [parameter(mandatory=$true)]
        $hvServer
    )
    $Results=@()
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'SessionLocalSummaryView'
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
$Sessions = Get-SessionLocalSummaryView -hvServer $hvServer
Disconnect-HVServer -Server $serverAddress -Confirm:$false
$sessions | select namesdata -ExpandProperty NamesData | Group-Object SecurityGatewayDns | select count,name

$sessions | select @{Name="State";Expression={$_.sessiondata.SessionState}}, @{Name="ConnectionServer";Expression={$_.namesdata.SecurityGatewayDns}} | group-object -property ConnectionServer,state | select count, name