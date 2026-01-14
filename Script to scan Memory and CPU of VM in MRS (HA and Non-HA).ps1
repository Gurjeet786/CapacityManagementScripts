#Script to scan Memory and CPU of VM in MRS : (HA and Non-HA) &  output name { VM_CPU&Memory_Scan_(HA/NonHA) }
 
# Get the hostname of the Hyper-V host
$hostName = $env:COMPUTERNAME

# Get all VMs on the host
$VMs = Get-VM

foreach ($vm in $VMs) {
    $vmName = $vm.Name
    $vmStatus = $vm.State
    $vmMemory = Get-VMMemory -VMName $vmName
    $vmCPU = Get-VMProcessor -VMName $vmName

    $startupMemory = $vmMemory.Startup / 1MB
    $minMemory = $vmMemory.Minimum / 1MB
    $maxMemory = $vmMemory.Maximum / 1MB
    $dynamicMemory = $vmMemory.DynamicMemoryEnabled
    $assignedMemory = $vm.MemoryAssigned / 1MB
    $currentMemoryUsage = $vm.MemoryDemand / 1MB
    $cpuCount = $vmCPU.Count

    $memoryType = if ($dynamicMemory) { "Dynamic" } else { "Fixed" }

    Write-Output "VM Name: $vmName"
    Write-Output "  Host Name: $hostName"
    Write-Output "  Status: $vmStatus"
    Write-Output "  Startup Memory (MB): $startupMemory"
    if ($dynamicMemory) {
        Write-Output "  Minimum Memory (MB): $minMemory"
        Write-Output "  Maximum Memory (MB): $maxMemory"
    }
    Write-Output "  Memory Type: $memoryType"
    Write-Output "  Assigned Memory (MB): $([math]::Round($assignedMemory, 2))"
    Write-Output "  Current Memory Usage (MB): $([math]::Round($currentMemoryUsage, 2))"
    Write-Output "  CPU Count: $cpuCount"
    Write-Output ""
}
