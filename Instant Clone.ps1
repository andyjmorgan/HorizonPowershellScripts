#this script demo's how to fork a running forked VM even with appstacks attached

Function New-InstantClone {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Date:          Apr 29, 2018
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .SYNOPSIS
        This function demonstrates the use of the new "Parentless" Instant Clone
        API that was introduced in vSphere 6.7
    .DESCRIPTION
        Function to create new "Parentless" Instant Clones in vSphere 6.7
    .EXAMPLE
        $SourceVM = "Foo"
        $newVMName = Foo-IC-1
        $guestCustomizationValues = @{
            "guestinfo.ic.hostname" = $newVMName
            "guestinfo.ic.ipaddress" = "192.168.30.10"
            "guestinfo.ic.netmask" = "255.255.255.0"
            "guestinfo.ic.gateway" = "192.168.30.1"
            "guestinfo.ic.dns" = "192.168.30.1"
        }
        New-InstantClone -SourceVM $SourceVM -DestinationVM $newVMName -CustomizationFields $guestCustomizationValues
    .NOTES
        Make sure that you have both a vSphere 6.7 env (VC/ESXi) as well as
        as the latest PowerCLI 10.1 installed which is reuqired to use vSphere 6.7 APIs
#>
    param(
        [Parameter(Mandatory=$true)][String]$SourceVM,
        [Parameter(Mandatory=$true)][String]$DestinationVM,
        [Parameter(Mandatory=$true)][Hashtable]$CustomizationFields
    )
    $vm = Get-VM -Name $SourceVM

    $config = @()
    $CustomizationFields.GetEnumerator() | Foreach-Object {
        $optionValue = New-Object VMware.Vim.OptionValue
        $optionValue.Key = $_.Key
        $optionValue.Value = $_.Value
        $config += $optionValue
    }

    # SourceVM must either be running or running but in Frozen State
    if($vm.PowerState -ne "poweredOn") {
        Write-Host -ForegroundColor Red "Instant Cloning is only supported on a PoweredOn or Frozen VM"
        break
    }

    # SourceVM == Powered On
    if((Get-VM $SourceVM).ExtensionData.Runtime.InstantCloneFrozen -eq $false) {

        # Retrieve all Network Adapters for SourceVM
        $vmNetworkAdapters = @()
        $devices = $vm.ExtensionData.Config.Hardware.Device
        foreach ($device in $devices) {
            if($device -is [VMware.Vim.VirtualEthernetCard]) {
                $vmNetworkAdapters += $device
            }
        }

        $spec = New-Object VMware.Vim.VirtualMachineInstantCloneSpec
        $locationSpec = New-Object VMware.Vim.VirtualMachineRelocateSpec

        # Disconect all NICs for new Instant Clone to ensure no dupe addresses on network
        # post-Instant Clone workflow needs to renable after uypdating GuestOS
        foreach ($vmNetworkAdapter in $vmNetworkAdapters) {
            $networkName = $vmNetworkAdapter.backing.deviceName
            $deviceConfigSpec = New-Object VMware.Vim.VirtualDeviceConfigSpec
            $deviceConfigSpec.Operation = "edit"
            $deviceConfigSpec.Device = $vmNetworkAdapter
            $deviceConfigSpec.Device.backing = New-Object VMware.Vim.VirtualEthernetCardNetworkBackingInfo
            $deviceConfigSpec.device.backing.deviceName = $networkName
            $connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
            $connectable.MigrateConnect = "disconnect"
            $deviceConfigSpec.Device.Connectable = $connectable
            $locationSpec.DeviceChange += $deviceConfigSpec
        }

        $spec.Config = $config
        $spec.Location = $locationSpec
        $spec.Name = $DestinationVM
    # SourceVM == Frozen
    } else {
        $spec = New-Object VMware.Vim.VirtualMachineInstantCloneSpec
        $locationSpec = New-Object VMware.Vim.VirtualMachineRelocateSpec
        $spec.Config = $config
        $spec.Location = $locationSpec
        $spec.Name = $DestinationVM
    }

    Write-Host "Creating Instant Clone $DestinationVM ..."
    $task = $vm.ExtensionData.InstantClone_Task($spec)
    $task1 = Get-Task -Id ("Task-$($task.value)")
    $task1 | Wait-Task | Out-Null
}

######Set Variables Here#####
$NewVMName = "icClone_2"
$sourceVMName = "10x64p1-1"
$destinationNetwork = "DMZ Network"
$vcenterAddress = "vcsa.lab.local"
#############################



$creds = Get-Credential -Message "Please enter vcenter credentials"

Connect-VIServer $vcenterAddress -Credential $creds

#set the name of the new clone
$guestCustomizationValues = @{
    "guestinfo.ic.hostname" = $NewVMName
}

# handle Non Persistent Disks (Disconnect them for the clone process)
$vm = get-vm $sourceVMName
$diskList = Get-HardDisk -vm $vm
$removeList = $diskList | ?{$_.persistence -eq "independentNonPersistent" -or $_.Persistence -eq "IndependentPersistent"}                                                                                                          
$removeList | Remove-HardDisk -Confirm:$false


# clone the VM and disconnect it
New-InstantClone -SourceVM $sourceVMName -DestinationVM $NewVMName -CustomizationFields $guestCustomizationValues

#Add the nonpersistent disks back in
foreach($disk in $removeList){
    #add back to new instant clone
    New-HardDisk -Persistence $disk.Persistence -DiskPath $disk.Filename -vm $NewVMName -Confirm:$false
    #add back to original vm
    New-HardDisk -Persistence $disk.Persistence -DiskPath $disk.Filename -vm $vm -Confirm:$false

}

#sets the network adapter to secure network and connects the network
Get-NetworkAdapter -vm $newVMName | Set-NetworkAdapter -Portgroup $DestinationNetwork -Confirm:$false
Get-NetworkAdapter -vm $newVMName | Set-NetworkAdapter -StartConnected $true -Connected $true -Confirm:$false

get-vm $newVMname | open-vmconsolewindow

start-sleep 15

#closes the connection to vcenter
Disconnect-VIServer -force -Confirm:$false -ErrorAction SilentlyContinue

