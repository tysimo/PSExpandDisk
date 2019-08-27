# PSExpandDisk

PowerShell script for expanding virtual disks.  

This script will expand a virtual hard disk in VMM and then extend the volume on the corresponding virtual machine.  

# Dependencies

PowerShell virtualmachinemanager module

# Parameters

### `-VMMServer`

Name of Virtual Machine Manager server the virtual machine exists on.

### `-VM`

Name of virtual machine to expand the disk on.

### `-Drive`

Drive letter to expand.

### `-NewSize`

The size in GB to expand the drive to.

### `-SpaceToAdd`

The additional space in GB to add to the current drive size. 

# Notes

The parameters `-NewSize` and `-SpaceToAdd` are mutually exclusive and cannot be used together.  
If neither is specified, the script will default to NewSize and prompt the user for a value. 

# Examples

Expand the C: drive on testvm01 to 100 GB.
```powershell
.\Expand-VirtualDisk.ps1 -VMMServer devvmm -VM testvm01 -Drive C -NewSize 100
```

Add an additional 10 GB of space to the D: drive on testvm01.
```powershell
.\Expand-VirtualDisk.ps1 -VMMServer devvmm -VM testvm01 -Drive D -SpaceToAdd 10
```

Expand the E: drive on testvm01 to the size specified when prompted.
```powershell
.\Expand-VirtualDisk.ps1 -VMMServer devvmm -VM testvm01 -Drive E
```
