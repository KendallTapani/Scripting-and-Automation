# Hardware and Software Inventory Report Generator
# This script collects hardware and software information from network computers
# and generates comprehensive inventory reports

# Parameters
param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerList = "", # Empty string means "all computers in AD"
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFolder = "C:\Reports\Inventory_$(Get-Date -Format 'yyyyMMdd')",
    
    [Parameter(Mandatory=$false)]
    [int]$MaxThreads = 10, # Maximum number of parallel operations
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeSoftware = $true, # Whether to include software inventory
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\InventoryReport_$(Get-Date -Format 'yyyyMMdd').log"
)

# Import required modules
Import-Module ActiveDirectory

# Start logging
Start-Transcript -Path $LogPath -Append
Write-Output "Inventory Report Script started at $(Get-Date)"

# Create output folder if it doesn't exist
if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    Write-Output "Created output directory: $OutputFolder"
}

# Get the list of computers to inventory
$Computers = @()
if ([string]::IsNullOrEmpty($ComputerList)) {
    Write-Output "No computer list specified. Getting all computers from Active Directory..."
    $Computers = (Get-ADComputer -Filter * -Properties Name).Name
    Write-Output "Found $($Computers.Count) computers in Active Directory."
}
elseif (Test-Path -Path $ComputerList) {
    Write-Output "Reading computer list from file: $ComputerList"
    $Computers = Get-Content -Path $ComputerList | Where-Object { $_ -match '\S' } # Skip empty lines
    Write-Output "Found $($Computers.Count) computers in the list."
}
else {
    Write-Output "Interpreting input as a single computer name: $ComputerList"
    $Computers = @($ComputerList)
}

# Hardware inventory function
function Get-HardwareInventory {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        Write-Verbose "Collecting hardware inventory from $ComputerName..."
        
        # Basic system information
        $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop
        $BIOS = Get-WmiObject -Class Win32_BIOS -ComputerName $ComputerName -ErrorAction Stop
        $OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop
        
        # Processor information
        $Processor = Get-WmiObject -Class Win32_Processor -ComputerName $ComputerName -ErrorAction Stop
        
        # Memory information
        $PhysicalMemory = Get-WmiObject -Class Win32_PhysicalMemory -ComputerName $ComputerName -ErrorAction Stop
        $TotalMemory = ($PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB
        
        # Disk information
        $Disks = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DriveType=3" -ErrorAction Stop
        
        # Network information
        $NetworkAdapters = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ComputerName -Filter "PhysicalAdapter=True" -ErrorAction Stop
        $NetworkConfigs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ComputerName -Filter "IPEnabled=True" -ErrorAction Stop
        
        # Create hardware inventory object
        $HardwareInventory = [PSCustomObject]@{
            ComputerName = $ComputerName
            Manufacturer = $ComputerSystem.Manufacturer
            Model = $ComputerSystem.Model
            SerialNumber = $BIOS.SerialNumber
            BIOSVersion = $BIOS.SMBIOSBIOSVersion
            OSName = $OS.Caption
            OSVersion = $OS.Version
            OSBuild = $OS.BuildNumber
            OSArchitecture = $OS.OSArchitecture
            LastBootTime = $OS.ConvertToDateTime($OS.LastBootUpTime)
            InstallDate = $OS.ConvertToDateTime($OS.InstallDate)
            ProcessorName = $Processor.Name
            ProcessorCores = $Processor.NumberOfCores
            ProcessorLogicalProcessors = $Processor.NumberOfLogicalProcessors
            TotalMemoryGB = [math]::Round($TotalMemory, 2)
            DiskInfo = ($Disks | ForEach-Object {
                "$($_.DeviceID) - $([math]::Round($_.Size / 1GB, 2)) GB (Free: $([math]::Round($_.FreeSpace / 1GB, 2)) GB)"
            }) -join " | "
            IPAddresses = ($NetworkConfigs | ForEach-Object { $_.IPAddress }) -join ", "
            MACAddresses = ($NetworkConfigs | ForEach-Object { $_.MACAddress }) -join ", "
            IsOnline = $true
            CollectionTime = Get-Date
        }
        
        return $HardwareInventory
    }
    catch {
        Write-Warning "Failed to collect hardware inventory from $ComputerName`: $_"
        # Return a minimal object with error information
        return [PSCustomObject]@{
            ComputerName = $ComputerName
            IsOnline = $false
            CollectionTime = Get-Date
            ErrorMessage = $_.Exception.Message
        }
    }
}

# Software inventory function
function Get-SoftwareInventory {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        Write-Verbose "Collecting software inventory from $ComputerName..."
        
        # Get installed software from registry
        $InstalledSoftware = @()
        
        # 64-bit software
        $InstalledSoftware += Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | 
            Where-Object { $_.DisplayName -ne $null } | 
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
        } -ErrorAction Stop
        
        # 32-bit software on 64-bit OS
        $InstalledSoftware += Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            if (Test-Path HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*) {
                Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | 
                Where-Object { $_.DisplayName -ne $null } | 
                Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
            }
        } -ErrorAction SilentlyContinue
        
        # Windows features and updates
        $WindowsFeatures = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Get-WindowsFeature | Where-Object { $_.Installed -eq $true } | Select-Object Name, DisplayName
        } -ErrorAction SilentlyContinue
        
        $WindowsUpdates = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Get-HotFix | Select-Object HotFixID, Description, InstalledOn
        } -ErrorAction SilentlyContinue
        
        # Create software inventory object
        $SoftwareInventory = [PSCustomObject]@{
            ComputerName = $ComputerName
            InstalledSoftware = $InstalledSoftware
            WindowsFeatures = $WindowsFeatures
            WindowsUpdates = $WindowsUpdates
            IsOnline = $true
            CollectionTime = Get-Date
        }
        
        return $SoftwareInventory
    }
    catch {
        Write-Warning "Failed to collect software inventory from $ComputerName`: $_"
        # Return a minimal object with error information
        return [PSCustomObject]@{
            ComputerName = $ComputerName
            IsOnline = $false
            CollectionTime = Get-Date
            ErrorMessage = $_.Exception.Message
        }
    }
}

# Create report files
$HardwareReportPath = Join-Path -Path $OutputFolder -ChildPath "HardwareInventory.csv"
$SoftwareReportPath = Join-Path -Path $OutputFolder -ChildPath "SoftwareInventory.csv"
$SummaryReportPath = Join-Path -Path $OutputFolder -ChildPath "InventorySummary.txt"
$DetailedReportFolder = Join-Path -Path $OutputFolder -ChildPath "DetailedReports"

# Create the detailed report folder
if (-not (Test-Path -Path $DetailedReportFolder)) {
    New-Item -ItemType Directory -Path $DetailedReportFolder -Force | Out-Null
}

# Initialize hardware results array
$HardwareResults = @()

# Initialize software results array if including software
$SoftwareResults = @()

# Use runspaces for parallel processing
$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $MaxThreads, $SessionState, $Host)
$RunspacePool.Open()

$Jobs = @()
$Progress = 0
$TotalComputers = $Computers.Count

foreach ($Computer in $Computers) {
    # Skip empty computer names
    if ([string]::IsNullOrWhiteSpace($Computer)) {
        continue
    }
    
    # Create hardware inventory runspace
    $HardwareScriptBlock = {
        param($ComputerName, $GetHardwareInventoryFunction)
        # Dot source the function
        . ([ScriptBlock]::Create($GetHardwareInventoryFunction))
        # Call the function
        Get-HardwareInventory -ComputerName $ComputerName
    }
    
    $HardwareJob = [PSCustomObject]@{
        Runspace = [PowerShell]::Create()
        Status = "Hardware"
        Computer = $Computer
    }
    #$function:Get-HardwareInventory.ToString()
    $HardwareJob.Runspace.RunspacePool = $RunspacePool
    [void]$HardwareJob.Runspace.AddScript($HardwareScriptBlock)
    [void]$HardwareJob.Runspace.AddArgument($Computer)
    [void]$HardwareJob.Runspace.AddArgument()
    $HardwareJob.Handle = $HardwareJob.Runspace.BeginInvoke()
    $Jobs += $HardwareJob
    
    # Create software inventory runspace if needed
    if ($IncludeSoftware) {
        $SoftwareScriptBlock = {
            param($ComputerName, $GetSoftwareInventoryFunction)
            # Dot source the function
            . ([ScriptBlock]::Create($GetSoftwareInventoryFunction))
            # Call the function
            Get-SoftwareInventory -ComputerName $ComputerName
        }
        
        $SoftwareJob = [PSCustomObject]@{
            Runspace = [PowerShell]::Create()
            Status = "Software"
            Computer = $Computer
        }
        #$function:Get-SoftwareInventory.ToString()
        $SoftwareJob.Runspace.RunspacePool = $RunspacePool
        [void]$SoftwareJob.Runspace.AddScript($SoftwareScriptBlock)
        [void]$SoftwareJob.Runspace.AddArgument($Computer)
        [void]$SoftwareJob.Runspace.AddArgument()
        $SoftwareJob.Handle = $SoftwareJob.Runspace.BeginInvoke()
        $Jobs += $SoftwareJob
    }
}

# Process completed jobs
while ($Jobs.Where({ -not $_.Handle.IsCompleted }).Count -gt 0) {
    # Update progress
    $CompletedJobs = $Jobs.Where({ $_.Handle.IsCompleted }).Count
    $Progress = [math]::Round(($CompletedJobs / $Jobs.Count) * 100, 0)
    Write-Progress -Activity "Collecting Inventory" -Status "$Progress% Complete" -PercentComplete $Progress

    # Wait a bit before checking again
    Start-Sleep -Milliseconds 500
}

# Process results
foreach ($Job in $Jobs) {
    try {
        $Result = $Job.Runspace.EndInvoke($Job.Handle)
        
        if ($Job.Status -eq "Hardware") {
            $HardwareResults += $Result
            
            # Write detailed hardware report for this computer if online
            if ($Result.IsOnline) {
                $HardwareDetailPath = Join-Path -Path $DetailedReportFolder -ChildPath "$($Result.ComputerName)_Hardware.txt"
                $HardwareDetail = @"
========================================================
Hardware Inventory Report for $($Result.ComputerName)
Generated on $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
========================================================

SYSTEM INFORMATION
-----------------
Manufacturer:      $($Result.Manufacturer)
Model:             $($Result.Model)
Serial Number:     $($Result.SerialNumber)
BIOS Version:      $($Result.BIOSVersion)

OPERATING SYSTEM
-----------------
OS Name:           $($Result.OSName)
OS Version:        $($Result.OSVersion)
OS Build:          $($Result.OSBuild)
OS Architecture:   $($Result.OSArchitecture)
Install Date:      $($Result.InstallDate)
Last Boot Time:    $($Result.LastBootTime)

PROCESSOR
-----------------
Processor Name:    $($Result.ProcessorName)
Physical Cores:    $($Result.ProcessorCores)
Logical Processors: $($Result.ProcessorLogicalProcessors)

MEMORY
-----------------
Total Memory:      $($Result.TotalMemoryGB) GB

STORAGE
-----------------
$($Result.DiskInfo -replace " \| ", "`r`n")

NETWORK
-----------------
IP Addresses:      $($Result.IPAddresses)
MAC Addresses:     $($Result.MACAddresses)

========================================================
"@
                $HardwareDetail | Out-File -FilePath $HardwareDetailPath -Force
            }
        }
        elseif ($Job.Status -eq "Software") {
            $SoftwareResults += $Result
            
            # Write detailed software report for this computer if online
            if ($Result.IsOnline -and $Result.InstalledSoftware) {
                $SoftwareDetailPath = Join-Path -Path $DetailedReportFolder -ChildPath "$($Result.ComputerName)_Software.txt"
                $SoftwareDetail = @"
========================================================
Software Inventory Report for $($Result.ComputerName)
Generated on $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
========================================================

INSTALLED SOFTWARE
-----------------
"@
                foreach ($Software in ($Result.InstalledSoftware | Sort-Object DisplayName)) {
                    $SoftwareDetail += @"
$($Software.DisplayName) - $($Software.DisplayVersion)
    Publisher: $($Software.Publisher)
    Install Date: $($Software.InstallDate)

"@
                }
                
                $SoftwareDetail += @"

WINDOWS FEATURES
-----------------
"@
                foreach ($Feature in ($Result.WindowsFeatures | Sort-Object DisplayName)) {
                    $SoftwareDetail += "$($Feature.DisplayName)`r`n"
                }
                
                $SoftwareDetail += @"

WINDOWS UPDATES
-----------------
"@
                foreach ($Update in ($Result.WindowsUpdates | Sort-Object InstalledOn -Descending)) {
                    $SoftwareDetail += @"
$($Update.HotFixID) - $($Update.Description) - Installed: $($Update.InstalledOn)
"@
                }
                
                $SoftwareDetail += @"

========================================================
"@
                $SoftwareDetail | Out-File -FilePath $SoftwareDetailPath -Force
            }
        }
    }
    catch {
        Write-Error "Error processing job for $($Job.Computer) ($($Job.Status)): $_"
    }
    finally {
        # Clean up runspace
        $Job.Runspace.Dispose()
    }
}

# Close the runspace pool
$RunspacePool.Close()
$RunspacePool.Dispose()

# Export hardware inventory to CSV
$HardwareResults | Select-Object ComputerName, Manufacturer, Model, SerialNumber, OSName, OSVersion, 
    ProcessorName, TotalMemoryGB, IPAddresses, IsOnline, CollectionTime |
    Export-Csv -Path $HardwareReportPath -NoTypeInformation
Write-Output "Hardware inventory report saved to $HardwareReportPath"

# Export software inventory summary to CSV if included
if ($IncludeSoftware) {
    # Create simplified software inventory for CSV export
    $SoftwareSummary = foreach ($Computer in $SoftwareResults) {
        if ($Computer.IsOnline -and $Computer.InstalledSoftware) {
            foreach ($Software in $Computer.InstalledSoftware) {
                [PSCustomObject]@{
                    ComputerName = $Computer.ComputerName
                    SoftwareName = $Software.DisplayName
                    Version = $Software.DisplayVersion
                    Publisher = $Software.Publisher
                    InstallDate = $Software.InstallDate
                }
            }
        }
        else {
            [PSCustomObject]@{
                ComputerName = $Computer.ComputerName
                SoftwareName = "N/A"
                Version = "N/A"
                Publisher = "N/A"
                InstallDate = "N/A"
                ErrorMessage = $Computer.ErrorMessage
            }
        }
    }
    
    $SoftwareSummary | Export-Csv -Path $SoftwareReportPath -NoTypeInformation
    Write-Output "Software inventory report saved to $SoftwareReportPath"
}

# Generate summary report
$OnlineComputers = $HardwareResults | Where-Object { $_.IsOnline } | Measure-Object | Select-Object -ExpandProperty Count
$OfflineComputers = $HardwareResults | Where-Object { -not $_.IsOnline } | Measure-Object | Select-Object -ExpandProperty Count

$Summary = @"
========================================================
Inventory Summary Report
Generated on $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
========================================================

SCAN RESULTS
-----------------
Total Computers Scanned: $($HardwareResults.Count)
Online Computers: $OnlineComputers
Offline Computers: $OfflineComputers

OPERATING SYSTEM SUMMARY
-----------------
"@

# Get OS distribution
$OSSummary = $HardwareResults | Where-Object { $_.IsOnline } | Group-Object -Property OSName | 
    Sort-Object -Property Count -Descending |
    ForEach-Object {
        "$(($_.Name).PadRight(30)): $($_.Count)"
    }

$Summary += $OSSummary -join "`r`n"

$Summary += @"

MANUFACTURER SUMMARY
-----------------
"@

# Get manufacturer distribution
$ManufacturerSummary = $HardwareResults | Where-Object { $_.IsOnline } | Group-Object -Property Manufacturer | 
    Sort-Object -Property Count -Descending |
    ForEach-Object {
        "$(($_.Name).PadRight(30)): $($_.Count)"
    }

$Summary += $ManufacturerSummary -join "`r`n"

if ($IncludeSoftware) {
    $Summary += @"

TOP 10 INSTALLED SOFTWARE
-----------------
"@

    # Get top 10 installed software
    $TopSoftware = $SoftwareSummary | Group-Object -Property SoftwareName | 
        Sort-Object -Property Count -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            "$(($_.Name).PadRight(50)): $($_.Count)"
        }

    $Summary += $TopSoftware -join "`r`n"
}

$Summary += @"

========================================================
"@

# Save summary report
$Summary | Out-File -FilePath $SummaryReportPath -Force
Write-Output "Summary report saved to $SummaryReportPath"

Write-Output "Inventory report generation completed at $(Get-Date)"
Stop-Transcript

# Examples of how to use this script:
# 
# 1. Generate inventory for all AD computers
# .\InventoryReport.ps1
# 
# 2. Generate inventory for specific computers in a text file (one per line)
# .\InventoryReport.ps1 -ComputerList "C:\computers.txt"
# 
# 3. Generate inventory for a single computer
# .\InventoryReport.ps1 -ComputerList "PC001"
# 
# 4. Hardware inventory only (skip software)
# .\InventoryReport.ps1 -IncludeSoftware:$false
# 
# 5. Custom output location
# .\InventoryReport.ps1 -OutputFolder "D:\Inventory\$(Get-Date -Format 'yyyyMMdd')"
