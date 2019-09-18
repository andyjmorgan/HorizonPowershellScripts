# this script demo's how to get a unique user logon count across an entire cpa at the time it is run

import-module vmware.powercli

function Get-GlobalSessionQuery{
    param(
        [parameter(mandatory=$true)]
        $hvServer,
        [parameter(mandatory=$true)]
        $pod
    )
    $Results=@()
    
    $queryspec = new-object VMware.Hv.GlobalSessionQueryServiceQuerySpec
    $queryspec.Pod = $pod
    $queryspec.MaxPageSize= 1

    $queryResponse = $hvserver.ExtensionData.GlobalSessionQueryService.GlobalSessionQueryService_QueryWithSpec($queryspec)
    $results+=$queryResponse.Results
    Write-Verbose "Received $($queryresponse.results.count)"
    if($queryResponse.RemainingCount -gt 0){
        Write-Verbose "Found further results to retrieve"
        $remaining=$queryResponse.RemainingCount
        do{
            
            $latestResponse = $hvserver.ExtensionData.GlobalSessionQueryService.GlobalSessionQueryService_GetNext($queryResponse.Id)
            $results+= $latestResponse.Results
            Write-Verbose "Pulled an additional $($latestResponse.Results.Count) item(s)"
            $remaining = $latestResponse.RemainingCount
        }while($remaining -gt 0)
    }

    $hvserver.ExtensionData.GlobalSessionQueryService.GlobalSessionQueryService_Delete($queryResponse.Id)

    $results
}

$serveraddress = "pod1hcon1.lab.local"
$creds = Get-Credential -Message "Please enter valid credentials to connect to the Horizon Connection servers"
$hvserver = Connect-HVServer $serveraddress -Credential $creds
$pods = $hvserver.ExtensionData.pod.Pod_List()
$sessionData=@()
$time = (get-date)
$sessionList=@()
foreach($pod in $pods){
    
    $sessionData+=Get-GlobalSessionQuery $hvserver $pod.id -Verbose
}


Disconnect-HVServer -Confirm:$false

foreach($session in $sessiondata){
    $hostingResource=""
    if($session.NamesData.BaseNames.DesktopName.Length -gt 0){
        $hostingResource = $session.NamesData.BaseNames.DesktopName
    }
    elseif($session.NamesData.BaseNames.FarmName.length -gt 0){
        $hostingResource = $session.NamesData.BaseNames.FarmName
    }
    $SessionObject = New-Object PSObject -Property @{
        username         = $session.NamesData.BaseNames.UserName
        domain           = $session.Namesdata.baseNames.username.split('\')[0]
        machineName      = $session.NamesData.BaseNames.MachineOrRDSServerName
        clientName       = $session.NamesData.BaseNames.ClientName
        SessionType      = $session.SessionData.SessionType
        SessionState     = $session.SessionData.SessionState
        SiteName         = $session.NamesData.SiteName
        PodName          = $session.namesData.PodName
        StartTime        = $session.SessionData.StartTime
        DisconnectTime   = $session.SessionData.DisconnectTime
        HostingResource  = $hostingResource
    }
    $sessionList+=$SessionObject
}

$podReport=@()
    $sessionList | group-object podname | %{
        $pod = new-object psobject -Property @{
            PodName = $_.name
            Count = $_.count
        }
        $podreport+=$pod
}

$siteReport=@()
    $sessionList | group-object sitename | %{
        $site = new-object psobject -Property @{
            siteName = $_.name
            Count = $_.count
        }
        $sitereport+=$site
}





$report = New-Object PSObject -Property @{
        timeStamp                 = $time
        totalUniqueCCU            = ($Sessionlist | group-object username).Count
        totalUniqueCCUApplication = ($Sessionlist | ?{$_.sessionType -eq "APPLICATION"} | group-object username).Count
        totalUniqueCCUbyClient    = ($Sessionlist | group-object username, clientname).Count
        totalSessions             = $sessionList.Count
        PodCounts                 = $podReport
        siteCounts                 = $siteReport

    }
$sessionlist