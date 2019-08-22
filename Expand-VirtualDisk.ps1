param ([String]$VMMServer,[String]$VM,[String]$Drive,[String]$NewSize) 

Import-Module -Name "virtualmachinemanager"

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