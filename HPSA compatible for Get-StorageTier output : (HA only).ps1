#HPSA compatible for Get-StorageTier output : (HA only) &  output name { Get_StorageTier_Report_HA }

# Get the server name
$serverName = $env:COMPUTERNAME

# Get the storage tier information
$storageTierInfo = Get-StorageTier

# Function to convert bytes to GB
function ConvertTo-GB($bytes) {
    return [math]::Round($bytes / 1GB, 2)
}

# Format the output
$output = @()
$output += "Server Name: $serverName"
$output += "Storage Tier Information:"

foreach ($tier in $storageTierInfo) {
    $output += "FriendlyName: $($tier.FriendlyName)"
    $output += "TierClass: $($tier.TierClass)"
    $output += "MediaType: $($tier.MediaType)"
    $output += "ResiliencySettingName: $($tier.ResiliencySettingName)"
    $output += "FaultDomainRedundancy: $($tier.FaultDomainRedundancy)"
    $output += "Size: $(ConvertTo-GB $tier.Size) GB"
    $output += "FootprintOnPool: $(ConvertTo-GB $tier.FootprintOnPool) GB"
    $output += "StorageEfficiency: $($tier.StorageEfficiency)"
    $output += ""
}

# Display the output
$output | Out-String

# Display a message indicating completion
Write-Host "Output has been displayed."
