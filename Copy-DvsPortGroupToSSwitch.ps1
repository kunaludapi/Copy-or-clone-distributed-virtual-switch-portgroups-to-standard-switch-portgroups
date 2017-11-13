#requires -version 4
<#
.SYNOPSIS
    Clone/Copy dvswitch (Distributed virtual switch) portgroups on standard virtual switch.
.DESCRIPTION
    The Copy-DvsPortGroupToSSwitch cmdlet creates new standard switch named 'SvSwitch100' on esxi host and clone portgroups from existing distributed standard switch and create it on 'SvSwitch100'.
.PARAMETER vCenter
    Prompts you for vCenter server FQDN or IP address to connect, vc parameter is an alias, This value can be taken from pipline by property name.
.PARAMETER Cluster
    Make sure you type a valid ClusterName within the provided vCenter server. New vSwitch name 'SvSwitch100' is created on all esxi hosts withing this cluster, and existing DvSwitch PortGroups cloned to newly vSwitch created.
.PARAMETER DVSwitch
    This ask for existing distributed virtual switch (dvswitch). All the portgroups from this distributed vswitch is copied to vSwitch 
.INPUTS
    VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl
    VMware.VimAutomation.Vds.Impl.V1.VmwareVDSwitchImpl
    VMware.VimAutomation.ViCore.Impl.V1.Host.Networking.VirtualPortGroupImpl
    VMware.VimAutomation.ViCore.Impl.V1.Host.Networking.VirtualSwitchImpl
.OUTPUTS
    VMware.VimAutomation.ViCore.Impl.V1.Host.Networking.VirtualPortGroupImpl
    VMware.VimAutomation.ViCore.Impl.V1.Host.Networking.VirtualSwitchImpl
.NOTES
  Version:        1.0
  Author:         Kunal Udapi
  Creation Date:  12 August 2017
  Purpose/Change: Clone or copy existing distributed virtual portgroups from dvswitch to Standard virtual switch
  Useful URLs: http://vcloud-lab.com
.EXAMPLE
    PS C:\>.\Copy-DvsPortGroupToSSwitch.ps1 -vCenter vcsa65.vcloud-lab.com -Cluster Cluster01 -DVSwitch DVSwitch-NonProd-01

    This command connects vcenter 'vcsa65.vcloud-lab.com', copy/clone dvswitch portgroups from 'DVSwitch-NonProd-01' and create new vswitch and copied portgroups on all esxi host in the cluster name 'cluster01'
#>
[CmdletBinding(SupportsShouldProcess=$True,
    ConfirmImpact='Medium', 
    HelpURI='http://vcloud-lab.com', 
    SupportsTransactions=$True)]
Param (
    [parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='Type vCenter server IP or FQDN you want to connect')]
    [alias('vc')]
    [String]$vCenter,
    [parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true, HelpMessage='Type valid Cluster Name within vCenter server')]
    [alias('c')]
    [String]$Cluster,
    [parameter(Position=2, Mandatory=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='Type valid distributed virtual switch (dvswitch) name')]
    [alias('dvs')]
    [String]$DVSwitch
)
Begin {
#$Cluster = 'Cluster01'
#$DVSwitch = 'DVSwitch-NonProd-01'
    if ( -not (Get-Module  vmware.vimautomation.core)) {
        Import-Module vmware.vimautomation.core
        Import-Module vmware.vimautomation.vds
    }
}
Process {
    if ($global:DefaultVIServers.Name -notcontains $vCenter) {
        try {
            Connect-VIServer $vCenter -ErrorAction Stop
        }
        catch {
            Write-Host $($Error[0].Exception) -ForegroundColor Red
            break
        }
    }
    try {
        $ClusterInfo = Get-Cluster $cluster -ErrorAction Stop
        $DvSwitchInfo = Get-VDSwitch -Name $DVSwitch -ErrorAction Stop
    }
    catch {
        Write-Host $($Error[0].Exception) -ForegroundColor Red
        break
    }

    $AllEsxis = $ClusterInfo | Get-VMhost
    $DvPortGroupInfo = $DvSwitchInfo | Get-VDPortgroup | Where-Object {$_.IsUplink -eq $false}

    foreach ($esxi in $ALLEsxis) {
        $ExistingSwitchs = $esxi | Get-VirtualSwitch
        $esxiName = $esxi.name
        if ($ExistingSwitchs.Name -notcontains 'SvSwitch100') {
            $vSwitch100 = $esxi | New-VirtualSwitch -Name SvSwitch100 -Mtu $DvSwitchInfo.Mtu
            $NvSwitchName = $vSwitch100.Name
            Write-Host "$([char]8734) " -ForegroundColor Magenta -NoNewline
            Write-Host "Created $NvSwitchName on $esxiName" -BackgroundColor Magenta 
            Foreach ($DvPortGroup in $DvPortGroupInfo) {
                $vPortGroupName = $DvPortGroup.Name
                $vLanID = $DvPortGroup.ExtensionData.Config.DefaultPortConfig.Vlan.VlanId
                $NewPortGroup = $vSwitch100 | New-VirtualPortGroup -Name $DvPortGroup.Name -VLanId $vLanID
                Write-Host "`t $([char]8730) " -ForegroundColor Green -NoNewline
                Write-Host "Created New PortGroup $vPortGroupName With vLanID $vLanID" -BackgroundColor DarkGreen
            }
        }
        else {
            Write-Host "$([char]215) " -ForegroundColor Red -NoNewline
            Write-Host "SvSwitch100 already present on $esxiName skipping..." -BackgroundColor DarkRed 
            Continue
        }
    }
}
End {
    Disconnect-VIServer $vCenter -Confirm:$false
}