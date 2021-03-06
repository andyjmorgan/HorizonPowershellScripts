﻿function Get-EventAlarmSummaryView{
    param(
        [parameter(mandatory=$true)]
        $hvServer
    )
    $Results=@()
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'EventSummaryView'
    $services = Get-ViewAPIService -hvServer $hvServer
    
    $OrFilter = New-Object VMware.Hv.QueryFilterOr
    $errorFilter = New-Object VMware.Hv.QueryFilterEquals
    $errorfilter.memberName = 'data.severity'
    $errorfilter.value = 'ERROR'
    $warningfilter = New-Object VMware.Hv.QueryFilterEquals
    $warningfilter.memberName = 'data.severity'
    $warningfilter.value = 'WARNING'
    $auditFilter = New-Object VMware.Hv.QueryFilterEquals
    $auditFilter.memberName = 'data.severity'
    $auditFilter.value = 'AUDIT_FAIL'
    $Orfilter.Filters+=$errorFilter
    $Orfilter.Filters+=$warningFilter
    $Orfilter.Filters+=$auditFilter

    $Andfilter = New-Object VMware.Hv.QueryFilterAnd
    
    $date=Get-Date

    $DateFilter = new-object VMware.Hv.QueryFilterBetween
    $DateFilter.FromValue = $date.AddDays(-20)
    $DateFilter.ToValue = $date
    $datefilter.MemberName= 'data.time'
    $Andfilter.Filters+=$DateFilter
    $andfilter.Filters+=$OrFilter
    $query.Filter = $AndFilter
    
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

    $date=Get-Date

    $DateFilter = new-object VMware.Hv.QueryFilterBetween
    $DateFilter.FromValue = $date.AddDays(-2)
    $DateFilter.ToValue = $date
    $datefilter.MemberName= 'data.time'
    $query.Filter = $DateFilter
    
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
#$logevents = Get-EventSummaryView $hvserver
#$CSList = $logevents | select data -ExpandProperty data | select node | group-object node | select name

$events = Get-EventAlarmSummaryView -hvServer $hvServer
$events | select data -ExpandProperty data | select time, eventtype, severity, message | ft  