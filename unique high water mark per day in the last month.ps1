# this script demo's how to get a unique user logon count per day from the eventdb
# Andrew Morgan EUC OCTO

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
#$creds = Get-Credential -Message "Please enter valid credentials to connect to the Horizon Connection servers"
foreach($server in $serveraddress){
    Write-host "Connecting to $server"
    $hvServer = Connect-HVServer -Server $server -Credential $creds
    $events = Get-EventSummaryView $hvserver -days 100
    Write-host "Retrieved $($events.count) events"
    $logevents += $events
    Disconnect-HVServer -Server $hvServer -Confirm:$false
}

$timedobjects = $logevents | select @{name="Event";expression={$_.data.eventtype}}, @{name="Date";Expression={$_.data.time}}, @{name="User";expression={$_.namesdata.userdisplayname}}, @{name="SID";expression={$_.namesdata.UserSid}} | sort date
$dayCountBreakdown = $timedobjects | select event, @{name="Day";Expression={$_.date.dayofyear}},user | Group-Object day

$UniqueHighWaterMarkReport=@()
[System.Collections.ArrayList]$spilloverlist= New-Object -TypeName "System.Collections.ArrayList"

foreach($day in $dayCountBreakdown){
    $daynumber = $day.name
    $highwaterMark = 0
   
    $logonsperday = 0
    $logoffsperday = 0
    $carriedForward=0

    $duplicateSessions = 0
    $missingsessions = 0

    [System.Collections.ArrayList]$loggedonUsers= New-Object -TypeName "System.Collections.ArrayList"

    if($spilloverlist.Count > 0){
        write-warning "Carrying over $($spilloverlist.count)"
        $carriedForward = $spilloverlist.Count
        $loggedonUsers = $spilloverlist
    }

    foreach($item in $day.group){
        if($item.event -eq "BROKER_USERLOGGEDIN"){
            $logonsperday+=1;
            $userSession = @($loggedonUsers | ? {$_.user -eq $item.User})
            if($userSession.Count -gt 1){
                write-warning "Found More than one user session"
            }
            if($userSession.count -eq 0){
                $newUser = new-object psobject -property @{
                    User = $item.User;
                    activeSessions = 1;
                }
                $loggedonUsers.Add($newUser) | out-null
            }
            if($userSession.count -eq 1){
                #write-warning "incrementing session count"

                $userSession[0].activeSessions +=1
            }
            if($loggedonusers.Count -gt $highwaterMark){
                    $highwaterMark = $loggedonusers.Count
            }
        }
        
        else{
            $logoffsperday+=1;
            $userSession = @($loggedonUsers | ? {$_.user -eq $item.User})
            if($userSession.Count -gt 1){
                write-warning "Found More than one user session"
            }
            if($userSession.count -eq 0){
                #write-warning "incrementing missing count"
               $missingsessions +=1
            }
            if($userSession.count -eq 1){
                $userSession[0].activeSessions -=1
                if($userSession[0].activeSessions -le 0)
                {
                    #write-warning "removing user session"
                    $loggedonUsers.Remove($userSession[0]) 
                }
                else{
                    #write-warning "decreasing user session count"
                }
            } 
        }
    
    }

    if($loggedonUsers.count -gt 0){
        Write-Warning "Carrying over $($loggedonUsers.Count) to next day"
        $spilloverlist = $loggedonUsers
    }

    $uniquehighwatermarkreport+=new-object psobject -property @{
        Date=(get-date -day 1 -month 1).AddDays($day.name -1).ToShortDateString();
        HighWaterMark=$highwatermark;
        logons=$logonsperday;
        logoffs=$logoffsperday;
        carryover= $spilloverlist.Count
    }
}

$UniqueHighWaterMarkReport | out-file "$env:USERPROFILE\uniquehighwatermarkreport.txt"
$logevents | out-file "$env:USERPROFILE\logevents.txt"
