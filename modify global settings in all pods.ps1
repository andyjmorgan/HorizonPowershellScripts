# this script demo's how to update global settings in pod along with modify connection server properties in pod.

import-module vmware.powercli

function CheckForSettingsUpdate(){
    [cmdletbinding(SupportsShouldProcess=$True)]
    param(
        [parameter(mandatory=$true)]
        [VMware.VimAutomation.HorizonView.Impl.V1.ViewServerImpl]$hvServer
    )
    #Gather Data from local pod
    $localMapEntryList = @()
        $podname = ($hvserver.ExtensionData.pod.Pod_List() | ?{$_.localpod}).displayname

    $globalsettings = $hvserver.ExtensionData.GlobalSettings.GlobalSettings_Get()
    if($globalsettings.GeneralData.SendDomainList -eq $null)
    {
        Write-Verbose "SendDomainList is Undefined in this pod ($podname), older version?"
    }
    elseif(!$globalsettings.GeneralData.SendDomainList){
        Write-Host "Updating SendDomainList Value"
        $SendDomainListEntry = new-object -TypeName VMware.Hv.MapEntry
        $SendDomainListEntry.Key = "generalData.sendDomainList"
        $SendDomainListEntry.Value = $true
        $localMapEntryList+=$sendDomainListEntry
    }


    if($globalsettings.GeneralData.HideDomainListInClient){
        write-host "Updating HideDomainListInClient"
        $HideDomainListInClient = New-Object -TypeName VMware.Hv.MapEntry
        $HideDomainListInClient.Key = "generalData.hideDomainListInClient"
        $HideDomainListInClient.Value = $false
        $localMapEntryList+=$HideDomainListInClient
    }
    if($localMapEntryList.count -gt 0){
        Write-Host "Updating Pod settings with $($localmapentrylist.count) values"
        if($PSCmdlet.ShouldProcess($podname,'Update')){
            return $hvserver.ExtensionData.GlobalSettings.GlobalSettings_Update($localMapEntryList)
        }
    }  
}

function AmmendConnectionServersAuth(){
     [cmdletbinding(SupportsShouldProcess=$True)]
    param(
        [parameter(mandatory=$true)]
        [VMware.VimAutomation.HorizonView.Impl.V1.ViewServerImpl]$hvServer
    )
    $conServers = $hvserver.ExtensionData.ConnectionServer.ConnectionServer_List()
    $kvp = New-Object -TypeName VMware.Hv.MapEntry
    $kvp.Key="general.discloseServicePrincipalName"
    $kvp.Value=$true
    foreach($cs in $conServers){
       try{
            [version]$version = $cs.general.version.split("-")[0]
            if($version.Major -ge 7 -and $version.Minor -ge 10){
                if($PSCmdlet.ShouldProcess($cs.general.name,'Update')){
                    write-host "Ammending Connection Server $($cs.general.name)"
                    $hvServer.ExtensionData.ConnectionServer.ConnectionServer_Update($cs.Id,$kvp)
                }
            }
            else{
                Write-Verbose "Skipped connection server $($cs.general.name) as it's not the correct version ($($cs.general.version))"
            }           
       }
       catch{
            Write-Warning "An error occurred while updating the connection server properties, not version 7.10?"
       }
    }
}



$serveraddress = Read-Host -Prompt "enter a connection server name to connect to"
$creds = Get-Credential -Message "Please enter valid credentials to connect to the Horizon Connection servers"
$hvserver = Connect-HVServer $serveraddress -Credential $creds

#Perform tasks on local pod
CheckForSettingsUpdate -hvServer $hvserver -Verbose -WhatIf  #Update Global Settings
AmmendConnectionServersAuth -hvServer $hvserver -verbose -WhatIf #Update each connection server properties

#List Pods
$pods = $hvserver.ExtensionData.pod.Pod_List()

#Perform task on Remote Pods
foreach($pod in $pods | ? {!$_.localPod}){   
    #try each endpoint one by one, if successful, will skip the rest.
    foreach($endpoint in $pod.endpoints){        
        $endpointDetails = $hvserver.ExtensionData.PodEndpoint.PodEndpoint_Get($endpoint); #Get endpoint details to try to connect to
        $connectionURI = [System.Uri] $endpointDetails.serverAddress # Generate a safe URI to connect to.
        $servername = $($connectionURI.DnsSafeHost) #Ensure it's a valid address
        

        try{
            Write-host "Connecting to $servername for Pod: $($pod.displayname)"
            $remoteHVserver = Connect-HVServer -Server $servername -Credential $creds

            write-host "Connected, attempting to perform global updates"
            CheckForSettingsUpdate -hvServer $remoteHVserver -Verbose -WhatIf
            
            write-host "Attempting to perform connection server updates"
            AmmendConnectionServersAuth -hvServer $remoteHVserver -verbose -WhatIf
            
            Disconnect-HVServer -Server $servername -Force -Confirm:$false
            break #we're outta here!
        }
        catch{
            #we failed, try another server in the pod
            Disconnect-HVServer -Server $servername -Force -Confirm:$false -ea SilentlyContinue
            write-warning "An error Occurred while connecting to the connection server: $connectionURI in Pod: $($pod.displayname)"
        }
    }
}

#close initial connection
Disconnect-HVServer -Server $serveraddress -Force -Confirm:$false -ea SilentlyContinue