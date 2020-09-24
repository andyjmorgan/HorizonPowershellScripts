#this script demo's how to pull image details about an instant clone desktop pool

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
$poolDisplayName = "Windows 10 Floating" # Pool Display name to be updated


$hvServer = Connect-HVServer -Server $serverAddress -Credential $creds

$DesktopPoolSummary = (Get-DesktopSummaryView -hvServer $hvServer -poolDisplayName $poolDisplayName).Results[0]
$DesktopPoolDetails = $hvServer.ExtensionData.Desktop.Desktop_Get($DesktopPoolSummary.Id)

$vCenter = $hvServer.ExtensionData.VirtualCenter.VirtualCenter_Get($DesktopPoolDetails.AutomatedDesktopData.VirtualCenter)

write-Host "PoolName: $($desktoppoolsummary.DesktopSummaryData.name)"
write-Host "vCenter: $($vcenter.serverspec.servername)"

write-host "lazy details:"

write-host "BaseVM: $($DesktopPoolDetails.AutomatedDesktopData.VirtualCenterNamesData.ParentVmPath.split("/")[-1])"
write-host "Snapshot: $($DesktopPoolDetails.AutomatedDesktopData.VirtualCenterNamesData.SnapshotPath.split("/")[-1])"

write-host "<-------------------------------------------------------------------------------------->"

write-host "Pendantic details:"

$vCenter = $hvServer.ExtensionData.VirtualCenter.VirtualCenter_Get($DesktopPoolDetails.AutomatedDesktopData.VirtualCenter)


$baseVM = $hvserver.ExtensionData.BaseImageVm.BaseImageVm_Get($DesktopPoolDetails.AutomatedDesktopData.VirtualCenterProvisioningSettings.VirtualCenterProvisioningData.ParentVm)
$baseSnapShot = $hvserver.ExtensionData.BaseImageSnapshot.BaseImageSnapshot_List($DesktopPoolDetails.AutomatedDesktopData.VirtualCenterProvisioningSettings.VirtualCenterProvisioningData.ParentVm) | 
Where-Object {$_.id.id -eq $DesktopPoolDetails.AutomatedDesktopData.VirtualCenterProvisioningSettings.VirtualCenterProvisioningData.snapshot.id}


write-host "BaseVM: $($basevm.name)"
write-host "Snapshot: $($basesnapshot.path.split("/")[-1])"