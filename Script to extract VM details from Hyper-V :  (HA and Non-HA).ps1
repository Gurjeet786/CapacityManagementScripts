#Script to extract VM details from Hyper-V :  (HA and Non-HA) &  output name { VM_ScanReport_(HA/NonHA) }

# Import the Hyper-V module
Import-Module Hyper-V

# Get the local computer name
$HostName = $env:COMPUTERNAME

# Initialize an array to store VM details
$VMDetails = @()

# Get all VMs on the local host
$VMs = Get-VM -ComputerName $HostName

foreach ($VM in $VMs) {
    # Get VM CPU and memory (convert memory to GB)
    $CPU = $VM.ProcessorCount
    $Memory = [math]::Round($VM.MemoryAssigned / 1GB, 2)

    # Get VM hard disk details
    $HardDisks = Get-VMHardDiskDrive -VMName $VM.Name | Where-Object { $_.Path -like "*.vhdx" }
    $DiskDetails = @()
    foreach ($Disk in $HardDisks) {
        $DiskInfo = Get-VHD -Path $Disk.Path
        $DiskDetails += [PSCustomObject]@{
            DiskName = $Disk.Name
            DiskSize = [math]::Round($DiskInfo.Size / 1GB, 2)
            IsFixed = if ($DiskInfo.VhdType -eq 'Fixed') { $true } else { $false }
        }
    }

    # Get VM status
    $VMStatus = $VM.State
    # Get VM host
    $VMHost = $VM.ComputerName

    # Add VM details to the array
    $VMDetails += [PSCustomObject]@{
        VMName = $VM.Name
        CPU = $CPU
        Memory = $Memory
        HardDisks = $DiskDetails
        Status = $VMStatus
        Host = $VMHost
    }
}

# Output the VM details
$VMDetails | ForEach-Object {
    Write-Output "VM Name: $($_.VMName)"
    Write-Output "Host: $($_.Host)"
    Write-Output "CPU: $($_.CPU)"
    Write-Output "Memory (GB): $($_.Memory)"
    Write-Output "Status: $($_.Status)"
    $_.HardDisks | ForEach-Object {
        Write-Output "Disk Name: $($_.DiskName)"
        Write-Output "Disk Size (GB): $($_.DiskSize)"
        Write-Output "Is Fixed Size: $($_.IsFixed)"
    }
    Write-Output ""
}
 
