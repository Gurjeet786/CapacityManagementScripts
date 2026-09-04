#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

<#
.SYNOPSIS
    Collects CPU, memory, and disk information from the local Hyper-V host
    and every virtual machine registered on that host.

.DESCRIPTION
    Host line includes:
      - Physical CPU sockets
      - Physical CPU cores
      - Logical CPU count
      - Installed memory
      - Every disk visible to the host (one by one)

    VM line includes:
      - CPU count
      - Memory type (Dynamic or Static)
      - Assigned memory (current runtime usage)
      - Startup memory
      - Minimum memory
      - Maximum memory
      - Every attached virtual disk (one by one), with configured size,
        current file size, VHD type, controller, and path

.PARAMETER OutputFile
    Optional path to a text file. When supplied, output is displayed on
    screen AND appended to this file.

.EXAMPLE
    .\Get-HyperVInventory.ps1

.EXAMPLE
    .\Get-HyperVInventory.ps1 -OutputFile "C:\Temp\HyperVInventory.txt"
#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [string]$OutputFile
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Helper: Returns TRUE if a string is null, empty, or whitespace only.
# Written using plain PowerShell operators (no static .NET method calls)
# to avoid syntax mistakes.
# ============================================================================

function Test-StringEmpty
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value)
    {
        return $true
    }

    if ($Value.Trim().Length -eq 0)
    {
        return $true
    }

    return $false
}

# ============================================================================
# Helper: Convert a byte count into a readable KB/MB/GB/TB/PB string.
# ============================================================================

function ConvertTo-ReadableSize
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Bytes
    )

    if ($null -eq $Bytes)
    {
        return "N/A"
    }

    $Size = 0.0
    $ParseSucceeded = [double]::TryParse(
        [string]$Bytes,
        [ref]$Size
    )

    if (-not $ParseSucceeded)
    {
        return "N/A"
    }

    if ($Size -ge 1PB)
    {
        return ("{0:N2} PB" -f ($Size / 1PB))
    }

    if ($Size -ge 1TB)
    {
        return ("{0:N2} TB" -f ($Size / 1TB))
    }

    if ($Size -ge 1GB)
    {
        return ("{0:N2} GB" -f ($Size / 1GB))
    }

    if ($Size -ge 1MB)
    {
        return ("{0:N2} MB" -f ($Size / 1MB))
    }

    if ($Size -ge 1KB)
    {
        return ("{0:N2} KB" -f ($Size / 1KB))
    }

    return ("{0:N0} Bytes" -f $Size)
}

# ============================================================================
# Helper: Display output on screen and append to the optional output file.
# ============================================================================

function Write-InventoryLine
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    Write-Host $Text -ForegroundColor Cyan

    if (-not (Test-StringEmpty -Value $script:OutputFile))
    {
        $Text | Out-File -FilePath $script:OutputFile -Append -Encoding UTF8
    }
}

# ============================================================================
# Validate and import the Hyper-V module.
# ============================================================================

try
{
    Import-Module Hyper-V -ErrorAction Stop
}
catch
{
    Write-Error ("Unable to load the Hyper-V PowerShell module. Error: {0}" -f $_.Exception.Message)
    return
}

# ============================================================================
# Prepare the optional output file.
# ============================================================================

if (-not (Test-StringEmpty -Value $OutputFile))
{
    try
    {
        $OutputFolder = Split-Path -Path $OutputFile -Parent

        if (-not (Test-StringEmpty -Value $OutputFolder))
        {
            if (-not (Test-Path -LiteralPath $OutputFolder))
            {
                New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
            }
        }

        if (Test-Path -LiteralPath $OutputFile)
        {
            Remove-Item -LiteralPath $OutputFile -Force -ErrorAction Stop
        }

        "Hyper-V Host and VM Hardware Inventory" | Out-File -FilePath $OutputFile -Encoding UTF8
        ("Collection Date : {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) | Out-File -FilePath $OutputFile -Append -Encoding UTF8
        ("Hyper-V Host    : {0}" -f $env:COMPUTERNAME) | Out-File -FilePath $OutputFile -Append -Encoding UTF8
        "" | Out-File -FilePath $OutputFile -Append -Encoding UTF8
    }
    catch
    {
        Write-Error ("Unable to initialize output file '{0}'. Error: {1}" -f $OutputFile, $_.Exception.Message)
        return
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "       HYPER-V HOST AND VM HARDWARE INVENTORY" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# SECTION 1: Hyper-V host inventory
# ============================================================================

try
{
    $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $Processors = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop)

    $HostName = $env:COMPUTERNAME
    $PhysicalCPUSockets = $Processors.Count
    $PhysicalCPUCores = ($Processors | Measure-Object -Property NumberOfCores -Sum).Sum
    $LogicalCPUCount = ($Processors | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    $HostMemory = ConvertTo-ReadableSize -Bytes $ComputerSystem.TotalPhysicalMemory

    $HostOutputParts = New-Object System.Collections.Generic.List[string]

    $HostOutputParts.Add("Server Name : $HostName")
    $HostOutputParts.Add("Type : Host")
    $HostOutputParts.Add("Physical CPU Sockets : $PhysicalCPUSockets")
    $HostOutputParts.Add("Physical CPU Cores : $PhysicalCPUCores")
    $HostOutputParts.Add("Logical CPU : $LogicalCPUCount")
    $HostOutputParts.Add("Memory : $HostMemory")

    # ------------------------------------------------------------------------
    # Every disk visible to the host, one by one
    # ------------------------------------------------------------------------

    try
    {
        $HostDisks = @(Get-Disk -ErrorAction Stop | Sort-Object -Property Number)

        if ($HostDisks.Count -eq 0)
        {
            $HostOutputParts.Add("Disks : No physical disks detected")
        }
        else
        {
            foreach ($Disk in $HostDisks)
            {
                $DiskSize = ConvertTo-ReadableSize -Bytes $Disk.Size

                if (Test-StringEmpty -Value $Disk.FriendlyName)
                {
                    $DiskName = "Unknown"
                }
                else
                {
                    $DiskName = $Disk.FriendlyName.Trim()
                }

                if ($null -eq $Disk.BusType)
                {
                    $BusType = "Unknown"
                }
                else
                {
                    $BusType = [string]$Disk.BusType
                }

                if ($null -eq $Disk.OperationalStatus)
                {
                    $DiskStatus = "Unknown"
                }
                else
                {
                    $DiskStatus = ($Disk.OperationalStatus -join "/")
                }

                $DiskLine = "Disk {0} : {1} [Name: {2}, Bus: {3}, Status: {4}]" -f `
                    $Disk.Number, $DiskSize, $DiskName, $BusType, $DiskStatus

                $HostOutputParts.Add($DiskLine)
            }
        }
    }
    catch
    {
        $HostOutputParts.Add(("Host Disk Collection Error : {0}" -f $_.Exception.Message))
    }

    $HostOutput = ($HostOutputParts -join ", ") + ";"
    Write-InventoryLine -Text $HostOutput
}
catch
{
    Write-Warning ("Unable to collect Hyper-V host information. Error: {0}" -f $_.Exception.Message)
}

# ============================================================================
# SECTION 2: Retrieve all VMs registered on the local Hyper-V host
# ============================================================================

try
{
    $VirtualMachines = @(Get-VM -ErrorAction Stop | Sort-Object -Property Name)
}
catch
{
    Write-Error ("Unable to retrieve virtual machines from host '{0}'. Error: {1}" -f $env:COMPUTERNAME, $_.Exception.Message)
    return
}

if ($VirtualMachines.Count -eq 0)
{
    Write-Warning ("No virtual machines were found on Hyper-V host '{0}'." -f $env:COMPUTERNAME)
}
else
{
    foreach ($VM in $VirtualMachines)
    {
        try
        {
            $VMOutputParts = New-Object System.Collections.Generic.List[string]

            # ------------------------------------------------------------
            # VM CPU
            # ------------------------------------------------------------

            try
            {
                $VMProcessor = Get-VMProcessor -VM $VM -ErrorAction Stop
                $VMCPUCount = $VMProcessor.Count
            }
            catch
            {
                $VMCPUCount = $VM.ProcessorCount
            }

            # ------------------------------------------------------------
            # VM memory
            # ------------------------------------------------------------

            try
            {
                $VMMemory = Get-VMMemory -VM $VM -ErrorAction Stop

                if ($VMMemory.DynamicMemoryEnabled)
                {
                    $MemoryType = "Dynamic"
                    $MinimumMemory = ConvertTo-ReadableSize -Bytes $VMMemory.Minimum
                    $MaximumMemory = ConvertTo-ReadableSize -Bytes $VMMemory.Maximum
                }
                else
                {
                    $MemoryType = "Static"
                    $MinimumMemory = "N/A - Static Memory"
                    $MaximumMemory = "N/A - Static Memory"
                }

                $StartupMemory = ConvertTo-ReadableSize -Bytes $VMMemory.Startup
            }
            catch
            {
                $MemoryType = "Unknown"
                $StartupMemory = ConvertTo-ReadableSize -Bytes $VM.MemoryStartup
                $MinimumMemory = "N/A"
                $MaximumMemory = "N/A"
            }

            $HasAssignedMemory = ($null -ne $VM.MemoryAssigned) -and ([double]$VM.MemoryAssigned -gt 0)

            if ($HasAssignedMemory)
            {
                $AssignedMemory = ConvertTo-ReadableSize -Bytes $VM.MemoryAssigned
            }
            else
            {
                $AssignedMemory = "0 GB (VM not running)"
            }

            $VMOutputParts.Add("Server Name : $($VM.Name)")
            $VMOutputParts.Add("Type : VM")
            $VMOutputParts.Add("State : $($VM.State)")
            $VMOutputParts.Add("CPU : $VMCPUCount")
            $VMOutputParts.Add("Memory Type : $MemoryType")
            $VMOutputParts.Add("Assigned Memory : $AssignedMemory")
            $VMOutputParts.Add("Startup Memory : $StartupMemory")
            $VMOutputParts.Add("Minimum Memory : $MinimumMemory")
            $VMOutputParts.Add("Maximum Memory : $MaximumMemory")

            # ------------------------------------------------------------
            # VM disks, one by one
            # ------------------------------------------------------------

            $DiskCollectionSucceeded = $true
            $VMHardDiskDrives = @()

            try
            {
                $VMHardDiskDrives = @(
                    Get-VMHardDiskDrive -VM $VM -ErrorAction Stop |
                        Sort-Object -Property ControllerType, ControllerNumber, ControllerLocation
                )
            }
            catch
            {
                $DiskCollectionSucceeded = $false
                $VMOutputParts.Add(("Disk Collection Error : {0}" -f $_.Exception.Message))
            }

            if ($DiskCollectionSucceeded)
            {
                if ($VMHardDiskDrives.Count -eq 0)
                {
                    $VMOutputParts.Add("Disks : No virtual disks attached")
                }
                else
                {
                    $DiskIndex = 0

                    foreach ($HardDiskDrive in $VMHardDiskDrives)
                    {
                        $DiskLabel = "Disk $DiskIndex"

                        $ControllerDetails = "{0} {1}:{2}" -f `
                            $HardDiskDrive.ControllerType, $HardDiskDrive.ControllerNumber, $HardDiskDrive.ControllerLocation

                        $HasPath = -not (Test-StringEmpty -Value $HardDiskDrive.Path)

                        if ($HasPath)
                        {
                            # Regular VHD / VHDX / AVHDX file
                            try
                            {
                                $VHDInformation = Get-VHD -Path $HardDiskDrive.Path -ErrorAction Stop

                                $ConfiguredDiskSize = ConvertTo-ReadableSize -Bytes $VHDInformation.Size
                                $CurrentFileSize = ConvertTo-ReadableSize -Bytes $VHDInformation.FileSize

                                if ($null -eq $VHDInformation.VhdType)
                                {
                                    $VHDType = "Unknown"
                                }
                                else
                                {
                                    $VHDType = [string]$VHDInformation.VhdType
                                }

                                $DiskLine = "{0} : {1} [Current File Size: {2}, VHD Type: {3}, Controller: {4}, Path: {5}]" -f `
                                    $DiskLabel, $ConfiguredDiskSize, $CurrentFileSize, $VHDType, $ControllerDetails, $HardDiskDrive.Path

                                $VMOutputParts.Add($DiskLine)
                            }
                            catch
                            {
                                $DiskLine = "{0} : Unable to read VHD information [Controller: {1}, Path: {2}, Error: {3}]" -f `
                                    $DiskLabel, $ControllerDetails, $HardDiskDrive.Path, $_.Exception.Message

                                $VMOutputParts.Add($DiskLine)
                            }
                        }
                        elseif ($null -ne $HardDiskDrive.DiskNumber)
                        {
                            # Pass-through disk
                            try
                            {
                                $PassThroughDisk = Get-Disk -Number $HardDiskDrive.DiskNumber -ErrorAction Stop
                                $PassThroughSize = ConvertTo-ReadableSize -Bytes $PassThroughDisk.Size

                                $DiskLine = "{0} : {1} [Pass-through Disk Number: {2}, Controller: {3}]" -f `
                                    $DiskLabel, $PassThroughSize, $HardDiskDrive.DiskNumber, $ControllerDetails

                                $VMOutputParts.Add($DiskLine)
                            }
                            catch
                            {
                                $DiskLine = "{0} : Pass-through disk information unavailable [Disk Number: {1}, Controller: {2}, Error: {3}]" -f `
                                    $DiskLabel, $HardDiskDrive.DiskNumber, $ControllerDetails, $_.Exception.Message

                                $VMOutputParts.Add($DiskLine)
                            }
                        }
                        else
                        {
                            $DiskLine = "{0} : Disk information unavailable [Controller: {1}]" -f $DiskLabel, $ControllerDetails
                            $VMOutputParts.Add($DiskLine)
                        }

                        $DiskIndex++
                    }
                }
            }

            $VMOutput = ($VMOutputParts -join ", ") + ";"
            Write-InventoryLine -Text $VMOutput
        }
        catch
        {
            Write-Warning ("Unable to collect information for VM '{0}'. Error: {1}" -f $VM.Name, $_.Exception.Message)
        }
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Inventory collection completed." -ForegroundColor Green

if (-not (Test-StringEmpty -Value $OutputFile))
{
    Write-Host "Output file : $OutputFile" -ForegroundColor Green
}

Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
