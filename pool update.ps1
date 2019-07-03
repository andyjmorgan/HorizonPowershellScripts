#this script demo's how to update a desktop pool with powershell

import-module vmware.powercli

function Get-DesktopSummaryView{
    param(
    [parameter(mandatory=$true)]
    $hvServer,
    [parameter(mandatory=$false)]
    $poolDisplayName
    )
    
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $query = New-Object VMware.Hv.QueryDefinition
    $query.queryEntityType = 'DesktopSummaryView'
    if($poolDisplayName -ne $null){
        $Filter = New-Object VMware.Hv.QueryFilterStartsWith
        $filter.memberName = 'desktopSummaryData.displayName'
        $filter.value = $poolDisplayName
        $query.Filter = $Filter
    }
    $services = Get-ViewAPIService -hvServer $hvServer
    $query_service_helper.QueryService_Query($services, $query)

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
$vCenterName="vcsa.lab.local" # vCenter address
$poolDisplayName = "10 x64" # Pool Display name to be updated
$vmName="10x64" # Golden Image VM name
$snapshotName="with yubikey driver" # Golden Image Snapshot name


$hvServer = Connect-HVServer -Server $serverAddress -Credential $creds

$DesktopPool = (Get-DesktopSummaryView -hvServer $hvServer -poolDisplayName $poolDisplayName).Results[0]
$vCenter = $hvServer.ExtensionData.VirtualCenter.VirtualCenter_List() | ? {$_.serverspec.servername -eq $vCenterName}
$baseVM = $hvServer.ExtensionData.BaseImageVm.BaseImageVm_List($vCenter.Id) | ?{$_.name -eq $vmName}
$BaseSnapshot = $hvServer.ExtensionData.BaseImageSnapshot.BaseImageSnapshot_List($baseVM.id) | ?{$_.name -eq $snapshotName}



$VMUpdateSpec = new-object VMware.Hv.DesktopPushImageSpec
$VMUpdateSpec.Settings = new-object VMware.Hv.DesktopPushImageSettings
$VMUpdateSpec.ParentVm = $baseVM.Id                                                                                                                                                      
$VMUpdateSpec.Snapshot = $BaseSnapshot.Id 
$VMUpdateSpec.Settings.LogoffSetting = "FORCE_LOGOFF" #Or "WAIT_FOR_LOGOFF"
$VMUpdateSpec.Settings.StopOnFirstError=$true
$VMUpdateSpec.Settings.StartTime = Get-Date #now

$hvServer.ExtensionData.Desktop.Desktop_SchedulePushImage($DesktopPool.Id,$VMUpdateSpec)
$PoolView = $hvServer.ExtensionData.Desktop.Desktop_GetDetailView($DesktopPool.Id)

