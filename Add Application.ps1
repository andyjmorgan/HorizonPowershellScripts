# this script demo's how to copy an application in a horizon pod

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

function Get-FarmSummaryView{
    param(
    [parameter(mandatory=$true)]
    $hvServer,
    [parameter(mandatory=$false)]
    $FarmDisplayName
    )
    
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'FarmSummaryView'
    if($FarmDisplayName -ne $null){
        $Filter = New-Object VMware.Hv.QueryFilterStartsWith
        $filter.memberName = 'data.displayName'
        $filter.value = $FarmDisplayName
        $query.Filter = $Filter
    }
    $services = Get-ViewAPIService -hvServer $hvServer
    $query_service_helper.QueryService_Query($services, $query)
}

function Get-ADUserOrGroupSummaryView{
    param(
    [parameter(mandatory=$true)]
    $hvServer,
    [parameter(mandatory=$false)]
    $ADGroupName
    )
    
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'ADUserOrGroupSummaryView'
    if($ADGroupName -ne $null){
        $Filter = New-Object VMware.Hv.QueryFilterStartsWith
        $filter.memberName = 'base.name'
        $filter.value = $ADGroupName
        $query.Filter = $Filter
    }
    $services = Get-ViewAPIService -hvServer $hvServer
    $query_service_helper.QueryService_Query($services, $query)
}

$creds = Get-Credential

$serverAddress = "pod1hcon1.lab.local" # Connection Server address
$farmDisplayName = "2016rdsh" # Farm Display name to add the application to
$adGroupName = "domain users"

$hvServer = Connect-HVServer -Server $serverAddress -Credential $creds
$farmQuery = Get-FarmSummaryView -FarmDisplayName $farmDisplayName -hvServer $hvServer  

if($farmQuery.Results.Count -gt 0){
    $farm = $farmQuery.Results[0]
    
    $NewApplicationSpec = New-Object VMware.Hv.ApplicationSpec
    $NewApplicationSpec.Data = New-Object VMware.Hv.ApplicationData
    $NewApplicationSpec.ExecutionData = New-Object VMware.Hv.ApplicationExecutionData


    $NewApplicationSpec.Data.name = "Paint_Test"                                                                                                                                           
    $NewApplicationSpec.data.DisplayName = "Paint"                                                                                                                                         
    $NewApplicationSpec.data.Description = "Testing automated publish"                                                                                                                       
    $NewApplicationSpec.data.Enabled = $true                                                                                                                                                 
    $NewApplicationSpec.data.EnablePreLaunch=$false                                                                                                                                          
    $NewApplicationSpec.ExecutionData.Farm = $farm.Id                                                                                                                                                                                                                                                                                          
    $NewApplicationSpec.ExecutionData.ExecutablePath="C:\Windows\system32\mspaint.exe"                                                                                                       
    $NewApplicationSpec.ExecutionData.Version = "1.0"                                                                                                                                                                                                                                                                                  
    $NewApplicationSpec.ExecutionData.StartFolder="C:\Windows\system32"   

    $newApp=$hvServer.ExtensionData.Application.Application_Create($NewApplicationSpec)
    if($newApp -ne $null){
        $adGroupQuery = Get-ADUserOrGroupSummaryView -hvServer $hvServer -ADGroupName $adGroupName
        if($adGroupQuery.Results.Count -eq 1){
            $adGroup = $adGroupQuery.results[0]
            $UserEntitlement = new-object VMware.Hv.UserEntitlementBase
            $UserEntitlement.Resource = $NewApp
            $userEntitlement.UserOrGroup = $adGroup.id
            $entitlementID = $hvServer.ExtensionData.UserEntitlement.UserEntitlement_Create($UserEntitlement)
            $entitlementID
        }
        else{
            Write-Warning "Application created, but could not create entitlement (more than one group found matching the provided group name)"
        }
    }
    else{
        Write-Warning "Application created, but could not create entitlement"
    }
} 
else{
    Write-Error "Could not find a farm called $farmDisplayName"
}