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

function Get-ApplicationInfo{
    param(
    [parameter(mandatory=$true)]
    $hvServer,
    [parameter(mandatory=$false)]
    $AppName
    )
    
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'ApplicationInfo'
    if($null -ne $AppName){
        $Filter = New-Object VMware.Hv.QueryFilterStartsWith
        $filter.memberName = 'data.name'
        $filter.value = $AppName
        $query.Filter = $Filter
    }
    $services = Get-ViewAPIService -hvServer $hvServer
    $query_service_helper.QueryService_Query($services, $query)
}

function Get-ApplicationEntitlementInfo{
    param(
    [parameter(mandatory=$true)]
    $hvServer,
    [parameter(mandatory=$false)]
    $AppID
    )
    
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'EntitledUserOrGroupLocalSummaryView'
    if($null -ne $AppName){
        $Filter = New-Object VMware.Hv.QueryFilterContains
        $filter.memberName = 'localData.applications'
        $filter.value = $AppID
        $query.Filter = $Filter
    }
    $services = Get-ViewAPIService -hvServer $hvServer
    $query_service_helper.QueryService_Query($services, $query)
}

$creds = Get-Credential

$serverAddress = "pod1hcon1.lab.local" # Connection Server address

$hvServer = Connect-HVServer -Server $serverAddress -Credential $creds
$AppQuery = Get-ApplicationInfo -hvServer $hvServer  

foreach($app in $AppQuery.Results){
   $entitlements =  Get-ApplicationEntitlementInfo -hvServer $hvServer -appid $app.Id.id

   $app = new-object -type psobject -Property @{
    Name = $app.Data.Name
    Id = $app.id 
    Data = $app.Data
    ExecutionData = $app.ExecutionData
    Entitlements = $entitlements.results.base.loginname     
   }
   $app
}