# PSExpandDisk

PowerShell script for expanding virtual disks.  

This scipt will expand a virtual hard disk in VMM and then extend the volumn on the corrosponding virtual machine.  

# Dependencies

PowerShell virtualmachinemanager module

# Parameters

### -VMMServer

Name of Virtual Machine Manager server the virtual machine exists on.

### -VM

Name of virtual machine to expand the disk on.

### -Drive

Drive letter to expand.

### -NewSize

The size in GB to expand the drive to.

# Examples

Expand C: drive on testvm01 to 100 GB.
```
.\Expand-VirtualDisk.ps1 -VMMServer devvmm -VM testvm01 -Drive C -NewSize 100
```

Expand D: drive on testvm01 to prompted value.
```
.\Expand-VirtualDisk.ps1 -VMMServer devvmm -VM testvm01 -Drive D
```
