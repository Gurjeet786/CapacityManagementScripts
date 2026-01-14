#Disk Mgmt output script : (HA and Non-HA) &  output name { MRS_DiskMgMT_Report_(HA/NonHA) }

# Get the server name
$serverName = $env:COMPUTERNAME
# Function to get disk information
function Get-DiskInfo {
   $disks = Get-Disk
   $partitions = Get-Partition
   $volumes = Get-Volume
   $diskInfo = @()
   foreach ($disk in $disks) {
       $diskDetails = [PSCustomObject]@{
           ServerName = $serverName
           DiskName = $disk.Number
           DiskSize = [math]::round($disk.Size / 1GB, 2)
           DiskStatus = $disk.OperationalStatus
           UnallocatedStorage = [math]::round(($disk.Size - ($partitions | Where-Object { $_.DiskNumber -eq $disk.Number } | Measure-Object Size -Sum).Sum) / 1GB, 2)
           Volumes = @()
       }
       foreach ($partition in $partitions | Where-Object { $_.DiskNumber -eq $disk.Number }) {
           if ($partition.AccessPaths -and $partition.AccessPaths[0]) {
               $volume = $volumes | Where-Object { $_.DriveLetter -eq $partition.AccessPaths[0].Substring(0,1) } -ErrorAction Ignore
               $volumeDetails = [PSCustomObject]@{
                   VolumeName = if ($volume.DriveLetter) { $volume.DriveLetter } else { "Unnamed" }
                   VolumeSize = [math]::round($partition.Size / 1GB, 2)
                   VolumeFileSystem = $volume.FileSystem
               }
               $diskDetails.Volumes += $volumeDetails
           }
       }
       $diskInfo += $diskDetails
   }
   return $diskInfo
}
# Get and display disk information
$diskInfo = Get-DiskInfo
foreach ($disk in $diskInfo) {
   Write-Host "Disk Name: Disk $($disk.DiskName)"
   Write-Host "Server Name: $($disk.ServerName)"
   Write-Host "Disk Size: $($disk.DiskSize) GB"
   Write-Host "Disk Status: $($disk.DiskStatus)"
   Write-Host "Unallocated Storage: $($disk.UnallocatedStorage) GB"
   Write-Host "Volumes:"
   foreach ($volume in $disk.Volumes) {
       Write-Host "  Volume Name: $($volume.VolumeName)"
       Write-Host "  Volume Size: $($volume.VolumeSize) GB"
       Write-Host "  Volume File System: $($volume.VolumeFileSystem)"
   }
   Write-Host "-----------------------------"
}
