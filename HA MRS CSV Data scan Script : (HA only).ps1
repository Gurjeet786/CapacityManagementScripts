#HA MRS CSV Data scan Script : (HA only) and output {CSV_DataScan_HA}

# PowerShell Script to Display CSV File/Folder Sizes in Hierarchical Format

# Get the local server name
$serverName = $env:COMPUTERNAME

# Get all CSV volumes
$csvVolumes = Get-ClusterSharedVolume

# Display server name
Write-Host "Server Name: $serverName" -ForegroundColor Cyan
Write-Host "----------------------------------------"

foreach ($csv in $csvVolumes) {
    $csvName = $csv.Name
    $csvPath = $csv.SharedVolumeInfo.FriendlyVolumeName

    # Extract the actual mount path (e.g., C:\ClusterStorage\Volume1)
    $mountPath = $csvPath -replace '^\\\\\?\\', ''

    if (Test-Path $mountPath) {
        Write-Host "`nCSV Name: $csvName" -ForegroundColor Yellow
        Write-Host "Path: $mountPath"
        Write-Host "Contents:" -ForegroundColor Green

        # Get all files and folders in the CSV root
        $items = Get-ChildItem -Path $mountPath -Recurse -Force -ErrorAction SilentlyContinue

        foreach ($item in $items) {
            try {
                $sizeGB = if ($item.PSIsContainer) {
                    $folderSize = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    [math]::Round($folderSize / 1GB, 2)
                } else {
                    [math]::Round($item.Length / 1GB, 2)
                }

                Write-Host "  $($item.FullName) - $sizeGB GB"
            } catch {
                Write-Warning "  Failed to process item: $($item.FullName)"
            }
        }
    } else {
        Write-Warning "Mount path not found: $mountPath"
    }
} 
