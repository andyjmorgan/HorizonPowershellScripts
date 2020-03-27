# this script demo's how to pull application info and detail
write-host -NoNewline "Importing Powercli..."
import-module vmware.powercli
write-host "< Done!"
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



function Get-HVApplicationInfo{
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

function Get-HVApplicationEntitlementInfo{
    param(
    [parameter(mandatory=$true)]
    $hvServer,
    [parameter(mandatory=$false)]
    $AppID
    )
    write-host $AppID
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'EntitledUserOrGroupLocalSummaryView'
    if($null -ne $AppID){
        $appArray=@($AppID)
        $Filter = New-Object VMware.Hv.QueryFilterContains
        $filter.memberName = 'localData.applications'
        $filter.value = $appArray
        $query.Filter = $Filter
    }
    $services = Get-ViewAPIService -hvServer $hvServer
    $query_service_helper.QueryService_Query($services, $query)
}

$creds = Get-Credential -Message "Please enter your Horizon administrator credentials."

$serverAddress = "pod1hcon1.lab.local" # Connection Server address

$hvServer = Connect-HVServer -Server $serverAddress -Credential $creds
$AppQuery = Get-HVApplicationInfo -hvServer $hvServer  
$entitlements = Get-HVApplicationEntitlementInfo -hvServer $hvserver

$results =@()
foreach($app in $AppQuery.Results){
   $appentitlements = $entitlements.Results | ? {$_.localdata.applications} | ?{$_.localdata.Applications.id.Contains($app.id.id)}

  $hostName = ""

   if($app.ExecutionData.Farm){
      $farm = $hvServer.ExtensionData.Farm.Farm_Get($app.ExecutionData.Farm)
      $hostName = $farm.Data.displayName
   }
   elseif($app.ExecutionData.Desktop){
      $desktop = $hvServer.ExtensionData.Desktop.Desktop_Get($app.ExecutionData.Desktop)
      $hostName = $desktop.base.displayName
     }
   

      $accessGroup = $hvServer.ExtensionData.AccessGroup.AccessGroup_Get($app.accessgroup)
     
      $entitlementsString = ""
      $appentitlements.base.loginname  | %{$entitlementsString += ($(if($entitlementsString){", "}) + $_ + $t)}
    
   $appOutput = new-object -type psobject -Property @{
    Name = $app.Data.Name
    Enabled = $app.Data.Enabled
    Displayname = $app.Data.DisplayName
    Description = $app.Data.Description
    Version = $app.ExecutionData.Version
    Publisher = $app.ExecutionData.ExecutablePath
    StartFolder = $app.ExecutionData.StartFolder
    Arguments = $app.ExecutionData.Args
    Prelaunch = $app.Data.EnablePreLaunch
    PoolOrFarm = $hostName
    Id = $app.id.id
    #Data = $app.Data
    #ExecutionData = $app.ExecutionData
    AcessGroup = $accessGroup.Base.Name
    
    Entitlements = $entitlementsString

   }
   $results+=$appOutput
}
$results | Export-Csv output.csv -NoTypeInformation -Force
Invoke-Item "output.csv"