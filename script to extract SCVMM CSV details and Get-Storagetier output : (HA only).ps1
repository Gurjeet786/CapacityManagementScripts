#Raw script to extract SCVMM CSV details and Get-Storagetier output : (HA only) &  output name { CSV&Get_StorageTier_Report_HA }

# Define the function to get cluster information
function Get-ClusterReport {
    # Get the cluster name from the local server
    $ClusterName = (Get-Cluster).Name

    # Get cluster nodes
    $nodes = Get-ClusterNode -Cluster $ClusterName

    # Get CSV details
    $csvs = Get-ClusterSharedVolume -Cluster $ClusterName | Select-Object Name, OwnerNode, @{Name="TotalSize(GB)";Expression={"{0:N2}" -f ($_.SharedVolumeInfo.Partition.Size / 1GB)}}, @{Name="FreeSize(GB)";Expression={"{0:N2}" -f ($_.SharedVolumeInfo.Partition.FreeSpace / 1GB)}}

    # Get Storage Pool details directly from the local machine
    $pools = Get-StoragePool | Select-Object FriendlyName, @{Name="TotalSize(GB)";Expression={"{0:N2}" -f ($_.Size / 1GB)}}, @{Name="UsedSize(GB)";Expression={"{0:N2}" -f ($_.AllocatedSize / 1GB)}}

    # Get Storage Tier details
    $tiers = Get-StorageTier | Select-Object FriendlyName, TierClass, MediaType, ResiliencySettingName, FaultDomainRedundancy, @{Name="TotalSize(GB)";Expression={"{0:N2}" -f ($_.Size / 1GB)}}, @{Name="FootprintOnPool(GB)";Expression={"{0:N2}" -f ($_.FootprintOnPool / 1GB)}}, @{Name="StorageEfficiency";Expression={"{0:N2}" -f ($_.StorageEfficiency)}}

    # Display the report
    Write-Host "Cluster Name: $ClusterName"
    Write-Host "Nodes in Cluster:"
    $nodes | ForEach-Object { Write-Host $_.Name }

    Write-Host "`nCluster Shared Volumes (CSVs):"
    $csvs | Format-Table -AutoSize

    Write-Host "`nStorage Pools:"
    if ($pools.Count -eq 0) {
        Write-Host "No storage pool details available."
    } else {
        $pools | Format-Table -AutoSize
    }

    Write-Host "`nStorage Tiers:"
    if ($tiers.Count -eq 0) {
        Write-Host "No storage tier details available."
    } else {
        $tiers | Format-Table -AutoSize
    }
}

# Example usage
Get-ClusterReport
