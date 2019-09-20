# this script demo's how to get a unique user logon count across an entire cpa at the time it is run

import-module vmware.powercli

function Get-LocalSessionQuery{
    param(
        [parameter(mandatory=$true)]
        $hvServer
    )
    $Results=@()
    
   $queryService = New-Object VMware.Hv.QueryServiceService
   $defn = New-Object VMware.Hv.QueryDefinition
   $defn.queryEntityType = 'SessionLocalSummaryView'
   
    $queryResponse = $queryService.QueryService_Create($hvserver.ExtensionData,$defn)
    $results+=$queryResponse.Results
    Write-Verbose "Received $($queryresponse.results.count)"
    if($queryResponse.RemainingCount -gt 0){
        Write-Verbose "Found further results to retrieve"
        $remaining=$queryResponse.RemainingCount
        do{
            
            $latestResponse = $queryService.QueryService_GetNext($hvserver.ExtensionData,$queryResponse.Id)
            $results+= $latestResponse.Results
            Write-Verbose "Pulled an additional $($latestResponse.Results.Count) item(s)"
            $remaining = $latestResponse.RemainingCount
        }while($remaining -gt 0)
    }

    $hvserver.ExtensionData.GlobalSessionQueryService.GlobalSessionQueryService_Delete($queryResponse.Id)

    $results
}


function convert-SessionsToReportObject(){
    param(
        [psobject]$sessionlist,
        [string]$siteName,
        [string]$podName
    )
    $List =@()
    Write-Verbose $($sessionList.Count)
    foreach($session in $sessionList){
        $hostingResource=""
        if($session.NamesData.DesktopName.Length -gt 0){
            $hostingResource = $session.NamesData.DesktopName
        }
        elseif($session.NamesData.FarmName.length -gt 0){
            $hostingResource = $session.NamesData.FarmName
        }
        $SessionObject = New-Object PSObject -Property @{
            username         = $session.NamesData.UserName
            domain           = $session.Namesdata.username.split('\')[0]
            machineName      = $session.NamesData.MachineOrRDSServerName
            clientName       = $session.NamesData.ClientName
            SessionType      = $session.SessionData.SessionType
            SessionState     = $session.SessionData.SessionState
            StartTime        = $session.SessionData.StartTime
            DisconnectTime   = $session.SessionData.DisconnectTime
            HostingResource  = $hostingResource
            PodName          = $podName
            SiteName         = $siteName
        }
    $List+=$SessionObject
    }
    return $List

}

$time = (get-date)
$sessionList=@()

$serveraddress = Read-Host -Prompt "enter a connection server name to connect to"
$creds = Get-Credential -Message "Please enter valid credentials to connect to the Horizon Connection servers"
$hvserver = Connect-HVServer $serveraddress -Credential $creds

#List Pods and Sites for reports
$pods = $hvserver.ExtensionData.pod.Pod_List()
$sites = $hvserver.ExtensionData.Site.Site_List()


#get Local Pod
$localPod = $pods | ?{$_.localpod}[0]
#Get Local Site
$localSite = $sites | ?{$_.id.id -eq $localPod.site.Id}[0]


#Gather Data from local pod
$localsessions = Get-LocalSessionQuery($hvserver)
Write-Verbose "Received $($localsessions.count) sessions from local pod"
$sessionList += convert-SessionsToReportObject -SessionList $localsessions -podName $localPod.DisplayName -siteName $localSite.base.displayname

#Perform task on Remote Pods

foreach($pod in $pods | ? {!$_.localPod}){
    
    $localSite = $sites | ?{$_.id.id -eq $pod.site.Id}[0]
    $hasData=$false
    foreach($endpoint in $pod.endpoints){        
        $endpointDetails = $hvserver.ExtensionData.PodEndpoint.PodEndpoint_Get($endpoint);
        $connectionURI = [System.Uri] $endpointDetails.serverAddress
        $servername = $($connectionURI.DnsSafeHost)
        try{
            Write-Verbose "Connecting to $servername for Pod: $($pod.displayname)"
            $remoteHVserver = Connect-HVServer -Server $servername -Credential $creds
            $remoteSessions = Get-LocalSessionQuery -hvServer $remoteHVserver
            Write-Verbose "Received $($remoteSessions.count) for Pod: $($Pod.displayname)"
            $sessionList += convert-SessionsToReportObject -SessionList $remoteSessions -podName $pod.DisplayName -siteName $localSite.base.displayname
            $hasData=$true
            Disconnect-HVServer -Server $servername -Force -Confirm:$false
            break
        }
        catch{
            Disconnect-HVServer -Server $servername -Force -Confirm:$false -ea SilentlyContinue
            write-warning "An error Occurred while connecting to the connection server: $connectionURL in Pod: $($pod.displayname)"
        }
    }
    if(!$hasData){
        write-error "Could not retrieve any data from remote pod: $($pod.displayname)"
    }
}

#close initial connection
Disconnect-HVServer -Server $serveraddress -Force -Confirm:$false -ea SilentlyContinue

Write-Verbose "Received a total of $($sessionList.count) sessions across the CPA"

#parse data
foreach($session in $sessiondata){
    $hostingResource=""
    if($session.NamesData.BaseNames.DesktopName.Length -gt 0){
        $hostingResource = $session.NamesData.DesktopName
    }
    elseif($session.NamesData.BaseNames.FarmName.length -gt 0){
        $hostingResource = $session.NamesData.FarmName
    }
    $SessionObject = New-Object PSObject -Property @{
        username         = $session.NamesData.UserName
        domain           = $session.Namesdata.username.split('\')[0]
        machineName      = $session.NamesData.MachineOrRDSServerName
        clientName       = $session.NamesData.ClientName
        SessionType      = $session.SessionData.SessionType
        SessionState     = $session.SessionData.SessionState
        StartTime        = $session.SessionData.StartTime
        DisconnectTime   = $session.SessionData.DisconnectTime
        HostingResource  = $hostingResource
    }
    $sessionList+=$SessionObject
}

$podReport = $sessionlist | group-object -

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

$domainReport=@()
    $sessionList | group-object domain | %{
        $domain = new-object psobject -Property @{
            domainname = $_.name
            Count = $_.count
        }
        $domainReport+=$domain

}


$report = New-Object PSObject -Property @{
        timeStamp                 = $time
        totalUniqueCCU            = @($Sessionlist | group-object username).Count
        totalUniqueCCUApplication = @($Sessionlist | ?{$_.sessionType -eq "APPLICATION"} | group-object username).Count
        totalUniqueCCUbyClient    = @($Sessionlist | group-object username, clientname).Count
        totalSessions             = $sessionList.Count
        PodCounts                 = $podReport
        siteCounts                = $siteReport
        domainCounts              = $domainReport
}
$report

