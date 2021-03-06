<#PSScriptInfo
.VERSION 1.2.1
.GUID 99179600-f3aa-402f-8c0d-7d790673df30
.AUTHOR Tyler Simonson
.TAGS VirtualMachineManager, VMM, SCVMM, HardDisk 
.PROJECTURI https://github.com/tysimo/PSExpandDisk
.EXTERNALMODULEDEPENDENCIES VirtualMachineManager 
.RELEASENOTES
#>

#Requires -Modules VirtualMachineManager

<# 
.SYNOPSIS 
PowerShell script for expanding virtual disks.  

.DESCRIPTION
This script will expand a virtual disk in VMM and then extend the volume on the corresponding virtual machine. 

.LINK
https://github.com/tysimo/PSExpandDisk

.PARAMETER VMMServer
Name of Virtual Machine Manager server the virtual machine exists on.

.PARAMETER VM
Name of virtual machine to expand the disk on.

.PARAMETER Drive
Drive letter to expand.

.PARAMETER NewSize
The size in GB to expand the drive to.

.PARAMETER SpaceToAdd
The additional space in GB to add to the current drive size. 

.NOTES
The parameters NewSize and SpaceToAdd are mutually exclusive and cannot be used together.  
If neither is specified, the script will default to NewSize and prompt the user for a value.   

.EXAMPLE
.\Expand-VirtualDisk.ps1 -VMMServer devvmm -VM testvm01 -Drive C -NewSize 100

Expand the C: drive on testvm01 to 100 GB.

.EXAMPLE
.\Expand-VirtualDisk.ps1 -VMMServer devvmm -VM testvm01 -Drive D -SpaceToAdd 10

Add an additional 10 GB of space to the D: drive on testvm01.

.EXAMPLE
.\Expand-VirtualDisk.ps1 -VMMServer devvmm -VM testvm01 -Drive E 

Expand the E: drive on testvm01 to the size specified when prompted.  The script will display the current drive size before asking for the new size.
#> 

[CmdletBinding(DefaultParameterSetName='NewSize')]
param (
	[Parameter(Mandatory = $true)]
	[string]	$VMMServer,

	[Parameter(Mandatory = $true)]
	[string]	$VM,

	[Parameter(Mandatory = $true)]
	[string]	$Drive,

	[Parameter(Mandatory = $false, ParameterSetName = 'NewSize')]
	[int] $NewSize,

	[Parameter(Mandatory = $true, ParameterSetName = 'SpaceToAdd')]
	[int] $SpaceToAdd
)

Import-Module -Name "VirtualMachineManager"

$DiskInfoScript = {
	param($Drive)
    $Number = ([string](Get-Partition -DriveLetter $Drive).DiskNumber).Replace(' ','')
    $Partition = (Get-Partition -DriveLetter $Drive | Where-Object -FilterScript {$_.Type -Eq "Basic"}).PartitionNumber
    $Size = (Get-Disk -Number $Number).Size
	Return $Number, $Partition, $Size
}
$ExtendScript = {
	param($DiskNumber,$PartitionNumber)
	$DiskPart = "select disk $DiskNumber
	list partition
	select partition $PartitionNumber
	extend" 
	$DiskPart | diskpart | Out-Null
}

Get-SCVMMServer -ComputerName $VMMServer | Out-Null

$DiskInfo = Invoke-Command -ComputerName $VM -ScriptBlock $DiskInfoScript -Argumentlist $Drive
$DiskNumber = $DiskInfo[0]
$PartitionNumber = $DiskInfo[1]
$Size = [math]::round($DiskInfo[2] / 1GB,1)
$Lun = (Get-WmiObject win32_diskdrive -ComputerName $VM | Where-Object {$_.DeviceID -like "\\.\PHYSICALDRIVE"+$DiskNumber}).SCSILogicalUnit

switch ($psCmdlet.ParameterSetName) 
{
	"NewSize" {
		If (!$NewSize)
		{
			Write-Host "Current size:"$Size -ForegroundColor "Yellow"
			$NewSize = Read-Host "New size"
		}
	}
	"SpaceToAdd" {
		$NewSize = $Size + $SpaceToAdd
	}
}

Write-Host "Expanding virtual disk in VMM..." -ForegroundColor "Yellow"
Get-SCVirtualMachine $VM | Get-SCVirtualDiskDrive | Where-Object {$_.Bus -eq 0 -and $_.Lun -eq $Lun} | Expand-SCVirtualDiskDrive -VirtualHardDiskSizeGB $NewSize | Out-Null

Write-Host "Extending volume on virtual machine..." -ForegroundColor "Yellow"
Invoke-Command -ComputerName $VM -ScriptBlock $ExtendScript -Argumentlist $DiskNumber,$PartitionNumber