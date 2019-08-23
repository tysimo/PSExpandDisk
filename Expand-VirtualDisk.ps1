<#PSScriptInfo
.VERSION 1.0.3
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
This scipt will expand a virtual hard disk in VMM and then extend the volumn on the corrosponding virtual machine. 

.PARAMETER VMMServer
Name of Virtual Machine Manager server the virtual machine exists on.

.PARAMETER VM
Name of virtual machine to expand the disk on.

.PARAMETER Drive
Drive letter to expand.

.PARAMETER NewSize
The size in GB to expand the drive to.

.EXAMPLE
.\Expand-VirtualDisk.ps1 -VMMServer devvmm -VM testvm01 -Drive C -NewSize 100

Expand C: drive on testvm01 to 100 GB.
#> 

param ([String]$VMMServer,[String]$VM,[String]$Drive,[String]$NewSize) 

Import-Module -Name "VirtualMachineManager"

If (!$VMMServer) {$VMMServer = Read-Host "VMM server"}
If (!$VM) {$VM = Read-Host "Virtual machine name"}
If (!$Drive) {$Drive = Read-Host "Drive letter"}

$VolumeScript = {
	param($Drive)
	$DiskID = (Get-Disk | Get-Partition | Where-Object {$_.driveletter -like $Drive}).disknumber
	$Lun = (Get-WmiObject win32_diskdrive | Where-Object {$_.DeviceID -like "\\.\PHYSICALDRIVE"+$DiskID})
	Return $Lun.scsilogicalunit
	}
$ExtendScript = {
	param($Drive)
	$Partition = Get-Partition -DriveLetter $Drive
	$PartitionNumber = $Partition.PartitionNumber 
	$DiskNumber = $Partition.DiskNumber
	$DiskPart = "select disk $DiskNumber
	list partition
	select partition $PartitionNumber
	extend" 
	$DiskPart | diskpart | Out-Null
	}

Get-SCVMMServer -ComputerName $VMMServer | Out-Null

$Drivex = $Drive + ":"	
$Disk = Get-WmiObject Win32_LogicalDisk -ComputerName $VM -Filter "DeviceID='$Drivex'" | Select-Object Size,FreeSpace	
$Size = [math]::round($Disk.size / 1GB,1)
$Lun2 = Invoke-Command -ComputerName $VM -ScriptBlock $VolumeScript -Argumentlist $Drive
$DriveName = (Get-SCVirtualDiskDrive -VM $VM | Where-Object {$_.lun -eq $Lun2}).VirtualHardDisk.Name + ".vhdx"
$DriveName = $DriveName.Replace(".vhdx.vhdx",".vhdx")

If (!$NewSize)
{
	Write-Host "Current size:"$Size -ForegroundColor "Yellow"
	$NewSize = Read-Host "New size"
}

Write-Host "Expanding virtual disk in VMM..." -ForegroundColor "Yellow"
If ($Drive -eq "C")
{
	Get-SCVirtualMachine $VM | Get-SCVirtualDiskDrive | Where-Object {$_.Bus -eq 0 -and $_.Lun -eq 0} | Expand-SCVirtualDiskDrive -VirtualHardDiskSizeGB $NewSize | Out-Null
}
Else
{
	Get-SCVirtualMachine $VM | Get-SCVirtualDiskDrive | Where-Object {$_.VirtualHardDisk.Location -like "*$DriveName"} | Expand-SCVirtualDiskDrive -VirtualHardDiskSizeGB $NewSize | Out-Null
}

Write-Host "Extending volume on virtual machine..." -ForegroundColor "Yellow"
Invoke-Command -ComputerName $VM -ScriptBlock $ExtendScript -Argumentlist $Drive