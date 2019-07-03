#this script shows how to update a horizon farm with powershell

import-module vmware.powercli

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
$farmDisplayName = "2016rdsh" # Farm Display name to be updated
$vmName="hv2016" # Golden Image VM name
$snapshotName="yubikey driver installed" # Golden Image Snapshot name


$hvServer = Connect-HVServer -Server $serverAddress -Credential $creds

$Farm = (Get-FarmSummaryView -hvServer $hvServer -FarmDisplayName $FarmDisplayName).Results[0]
$vCenter = $hvServer.ExtensionData.VirtualCenter.VirtualCenter_List() | ? {$_.serverspec.servername -eq $vCenterName}
$baseVM = $hvServer.ExtensionData.BaseImageVm.BaseImageVm_List($vCenter.Id) | ?{$_.name -eq $vmName}
$BaseSnapshot = $hvServer.ExtensionData.BaseImageSnapshot.BaseImageSnapshot_List($baseVM.id) | ?{$_.name -eq $snapshotName}

$FMUpdateSpec = New-Object VMware.Hv.FarmMaintenanceSpec
$FMUpdateSpec.LogoffSetting = "FORCE_LOGOFF" # or "WAIT_FOR_LOGOFF"
$FMUpdateSpec.ScheduledTime = Get-Date #now
$FMUpdateSpec.StopOnFirstError = $true
$FMUpdateSpec.MaintenanceMode = "IMMEDIATE" # "RECURRING"
$FMUpdateSpec.ImageMaintenanceSettings = New-Object VMware.Hv.FarmImageMaintenanceSettings
$FMUpdateSpec.ImageMaintenanceSettings.ParentVm = $baseVM.Id
$FMUpdateSpec.ImageMaintenanceSettings.Snapshot = $BaseSnapshot.Id


$hvServer.ExtensionData.Farm.Farm_ScheduleMaintenance($Farm.Id,$FMUpdateSpec)
