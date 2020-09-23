import-module vmware.powercli

function Get-GlobalEntitlements{
    param(
        [parameter(mandatory=$true)]
        $hvServer
    )
    $Results=@()
    
   $queryService = New-Object VMware.Hv.QueryServiceService
   $defn = New-Object VMware.Hv.QueryDefinition
   $defn.queryEntityType = 'GlobalEntitlementSummaryView'
    $queryResponse = $queryService.QueryService_Create($hvserver.ExtensionData,$defn)
    $results+=$queryResponse.Results
    Write-Verbose "[$($hvServer.name)] - Global Entitlement Query Received $($queryresponse.results.count)"
    if($queryResponse.RemainingCount -gt 0){
        Write-Verbose "Global Entitlement Query Found further results to retrieve"
        $remaining=$queryResponse.RemainingCount
        do{
            
            $latestResponse = $queryService.QueryService_GetNext($hvserver.ExtensionData,$queryResponse.Id)
            $results+= $latestResponse.Results
            Write-Verbose "[$($hvServer.name)] - Global Entitlement Query Pulled an additional $($latestResponse.Results.Count) item(s)"
            $remaining = $latestResponse.RemainingCount
        }while($remaining -gt 0)
    }

    $hvserver.ExtensionData.GlobalSessionQueryService.GlobalSessionQueryService_Delete($queryResponse.Id)

   $results
}


function Get-GlobalEntitlementEntitledUsers{
    param(
        [parameter(mandatory=$true)]
        $hvServer,
        [parameter(mandatory=$true)]
        $entitlementID
    )
    $Results=@()
    
   $queryService = New-Object VMware.Hv.QueryServiceService
   $defn = New-Object VMware.Hv.QueryDefinition
   $defn.queryEntityType = 'EntitledUserOrGroupGlobalSummaryView'
  $defn.Filter = new-object VMware.Hv.QueryFilterContains
 $defn.Filter.MemberName = 'globalData.globalEntitlements'
   $defn.Filter.Value = $entitlementID
    $queryResponse = $queryService.QueryService_Create($hvserver.ExtensionData,$defn)
    $results+=$queryResponse.Results
    Write-Verbose "[$($hvServer.name)] - Global Entitlement Query Received $($queryresponse.results.count)"
    if($queryResponse.RemainingCount -gt 0){
        Write-Verbose "Global Entitlement Query Found further results to retrieve"
        $remaining=$queryResponse.RemainingCount
        do{
            
            $latestResponse = $queryService.QueryService_GetNext($hvserver.ExtensionData,$queryResponse.Id)
            $results+= $latestResponse.Results
            Write-Verbose "[$($hvServer.name)] - Global Entitlement Query Pulled an additional $($latestResponse.Results.Count) item(s)"
            $remaining = $latestResponse.RemainingCount
        }while($remaining -gt 0)
    }

    $hvserver.ExtensionData.GlobalSessionQueryService.GlobalSessionQueryService_Delete($queryResponse.Id)

   $results
}

$creds = Get-Credential
$serverAddress = "pod1hcon1.lab.local" # Connection Server address


$hvServer = Connect-HVServer -Server $serverAddress -Credential $creds

$globalEntitlements = Get-GlobalEntitlements -hvServer $hvServer

foreach($globalEntitlement in $globalEntitlements){
    Write-Host "Checking memberships for $($globalEntitlement.base.DisplayName)"
    [VMware.Hv.GlobalEntitlementId[]] $idArray = @()
    $idArray+= $globalEntitlement.Id
    $globalEntitlementEntitlements = @(Get-GlobalEntitlementEntitledUsers -hvServer $hvServer -entitlementID $idArray)
    Write-Host "Found $($globalEntitlementEntitlements.Count) Entitlements"
    if($globalEntitlementEntitlements.Count -gt 0){
        foreach($entry in $globalEntitlementEntitlements){
            Write-Host "Entitled User or Group: $($entry.base.displayname)"
        }
    }
}