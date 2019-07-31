# this script demo's how to get a unique user logon count per day from the eventdb

import-module vmware.powercli

function Get-EventSummaryView{
    param(
        [parameter(mandatory=$true)]
        $hvServer,
        [parameter(mandatory=$false)]
        $days = 7
    )
    $Results=@()
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'EventSummaryView'
    $services = Get-ViewAPIService -hvServer $hvServer
    
    $OrFilter = New-Object VMware.Hv.QueryFilterOr
    $loggedInFilter = New-Object VMware.Hv.QueryFilterEquals
    $loggedinfilter.memberName = 'data.eventType'
    $loggedinfilter.value = 'BROKER_USERLOGGEDIN'
    $loggedoutfilter = New-Object VMware.Hv.QueryFilterEquals
    $loggedoutfilter.memberName = 'data.eventType'
    $loggedoutfilter.value = 'BROKER_USERLOGGEDOUT'
    $Orfilter.Filters+=$loggedInFilter
    $Orfilter.Filters+=$loggedoutfilter

    $Andfilter = New-Object VMware.Hv.QueryFilterAnd
    
    $date=Get-Date -Hour 0 -Minute 00 -Second 00

    $DateFilter = new-object VMware.Hv.QueryFilterBetween
    $DateFilter.FromValue = $date.AddDays(- $days)
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

$logevents = @()
$serveraddress = @("pod1hcon1.lab.local","pod2hcon1.lab.local")
$creds = Get-Credential -Message "Please enter valid crendentials to connect to the Horizon Connection servers"
foreach($server in $serveraddress){
    Write-host "Connecting to $server"
    $hvServer = Connect-HVServer -Server $server -Credential $creds
    $events = Get-EventSummaryView $hvserver -days 30
    Write-host "Retrieved $($events.count) events"
    $logevents += $events
    Disconnect-HVServer -Server $hvServer -Confirm:$false
}


$logevents | ?{$_.data.eventtype -eq "BROKER_USERLOGGEDIN"} |  
    select @{name="Event";expression={$_.data.eventtype}}, @{name="Day";Expression={$_.data.time.day}}, @{name="User";expression={$_.namesdata.userdisplayname}} -Unique | 
        group-object day | 
            select @{name="DayOfMonth"; expression = {$_.name}},@{name="UniqueUserLogons";expression={$_.count}}
