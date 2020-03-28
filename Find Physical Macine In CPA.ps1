# this script demo's how to find a machine by name in a CPA environment.

import-module vmware.powercli

function Get-MachineDetailsQuery{
    param(
        [parameter(mandatory=$true)]
        $hvServer,
        [parameter(mandatory=$true)]
        $machineName
    )
    $Results=@()
    
   $queryService = New-Object VMware.Hv.QueryServiceService
   $defn = New-Object VMware.Hv.QueryDefinition
   $defn.queryEntityType = 'MachineDetailsView'
   $defn.Filter = new-object VMware.Hv.QueryFilterOr
   $EqualsFilter = new-object VMware.Hv.QueryFilterEquals
   $EqualsFilter.memberName = 'data.name'
   $EqualsFilter.value = $machineName
   $ContainsFilter = new-object VMware.Hv.QueryFilterContains
   $ContainsFilter.memberName = 'data.name'
   $ContainsFilter.value = $machineName
   $defn.Filter.Filters += $EqualsFilter
   $defn.Filter.Filters += $containsFilter
    $queryResponse = $queryService.QueryService_Create($hvserver.ExtensionData,$defn)
    $results+=$queryResponse.Results
    Write-Verbose "[$($hvServer.name)] - Machine Query Received $($queryresponse.results.count)"
    if($queryResponse.RemainingCount -gt 0){
        Write-Verbose "Machine Query Found further results to retrieve"
        $remaining=$queryResponse.RemainingCount
        do{
            
            $latestResponse = $queryService.QueryService_GetNext($hvserver.ExtensionData,$queryResponse.Id)
            $results+= $latestResponse.Results
            Write-Verbose "[$($hvServer.name)] - Machine Query Pulled an additional $($latestResponse.Results.Count) item(s)"
            $remaining = $latestResponse.RemainingCount
        }while($remaining -gt 0)
    }

    $hvserver.ExtensionData.GlobalSessionQueryService.GlobalSessionQueryService_Delete($queryResponse.Id)

   $results
}

function convertMachinesToReturnObject{
    param(
        [parameter(mandatory=$true)]
        [VMware.Hv.MachineDetailsView[]]$Machines

    )

    $results = @()

    foreach($machine in $machines){
        if($machine.data.assignedUserNames){
            $results += New-Object -type psobject -Property @{
                MachineName = $machine.data.name
                AssignedUsers = $machine.data.assignedUserNames
                PoolName = $machine.desktopData.name
                PodName = $localPod.displayName
            }
        }
        else{
            $results += New-Object -type psobject -Property @{
                MachineName = $machine.data.name
                AssignedUsers = $machine.data.AssignedUserName
                PoolName = $machine.desktopData.name
                PodName = $localPod.displayName
            }
        }   
    }
    $results
}
function Get-CPAMachines{
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true)]
        [string]$machineName,
        [parameter(mandatory=$true)]
        [string]$connectionServerName,
        [parameter(mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credentials
    )

    $Results=@()
    Write-Verbose "Connecting to $connectionServerName and searching for $machineName"
    $hvserver = Connect-HVServer $connectionServerName -Credential $creds

    If($hvserver){
        $pods = $hvserver.ExtensionData.pod.Pod_List()
        $localPod = $pods | Where-Object{$_.localpod}[0]
        $Machines = @(Get-MachineDetailsQuery -hvServer $hvserver -machineName $machineName)
        
        if($machines){
            $results += convertMachinesToReturnObject -Machines $Machines
        }

        foreach($pod in $pods | Where-Object {!$_.localPod}){
    
            foreach($endpoint in $pod.endpoints){        
                $endpointDetails = $hvserver.ExtensionData.PodEndpoint.PodEndpoint_Get($endpoint)

                $connectionURI = [System.Uri] $endpointDetails.serverAddress
                $servername = $($connectionURI.DnsSafeHost)
                try{
                    Write-Verbose "Connecting to $servername for Pod: $($pod.displayname)"
                    $remoteHVserver = Connect-HVServer -Server $servername -Credential $creds
                    $remoteMachines = Get-MachineDetailsQuery -hvServer $remoteHVserver -machineName $machineName
                    Write-Verbose "Received $($remoteMachines.count) for Pod: $($Pod.displayname)"
                    Disconnect-HVServer -Server $servername -Force -Confirm:$false
                    break
                }
                catch{
                    Disconnect-HVServer -Server $servername -Force -Confirm:$false -ea SilentlyContinue
                    write-warning "An error Occurred while connecting to the connection server: $connectionURL in Pod: $($pod.displayname)"
                }
            } 
            if($remotemachines){
                $results += convertMachinesToReturnObject -Machines $remoteMachines
            }          
            
        }
        $results
    }
    else{
        write-warning "Could not connect to connection server $connectionServerName"
    }
}



