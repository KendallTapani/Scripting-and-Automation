# Hardware and Software Inventory Report Script
# This script generates detailed reports of hardware and software inventory for domain computers

# Import required modules
Import-Module ActiveDirectory
Import-Module CimCmdlets

# Function to validate admin rights
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to get hardware information
function Get-HardwareInfo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    try {
        $hardware = @{
            ComputerName = $ComputerName
            Processor = (Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Processor).Name
            Memory = [math]::Round((Get-CimInstance -ComputerName $ComputerName -ClassName Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)
            DiskSpace = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | 
                Select-Object DeviceID, @{N='Size(GB)';E={[math]::Round($_.Size/1GB, 2)}}, @{N='FreeSpace(GB)';E={[math]::Round($_.FreeSpace/1GB, 2)}}
            NetworkAdapters = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_NetworkAdapter | Where-Object {$_.PhysicalAdapter -eq $true} |
                Select-Object Name, AdapterType, MACAddress
        }
        return $hardware
    }
    catch {
        Write-Host "Error getting hardware info for $ComputerName`: $_" -ForegroundColor Red
        return $null
    }
}

# Function to get software information
function Get-SoftwareInfo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    try {
        $software = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Product |
            Select-Object Name, Version, Vendor, InstallDate |
            Sort-Object Name
        return $software
    }
    catch {
        Write-Host "Error getting software info for $ComputerName`: $_" -ForegroundColor Red
        return $null
    }
}

# Function to generate HTML report
function New-InventoryReport {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    $hardware = Get-HardwareInfo -ComputerName $ComputerName
    $software = Get-SoftwareInfo -ComputerName $ComputerName
    
    $htmlReport = @"
    <html>
    <head>
        <title>Inventory Report for $ComputerName</title>
        <style>
            body { font-family: Arial, sans-serif; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #4CAF50; color: white; }
            tr:nth-child(even) { background-color: #f2f2f2; }
        </style>
    </head>
    <body>
        <h1>Inventory Report for $ComputerName</h1>
        <h2>Hardware Information</h2>
        <table>
            <tr><th>Component</th><th>Details</th></tr>
            <tr><td>Processor</td><td>$($hardware.Processor)</td></tr>
            <tr><td>Memory (GB)</td><td>$($hardware.Memory)</td></tr>
        </table>
        
        <h3>Disk Information</h3>
        <table>
            <tr><th>Drive</th><th>Size (GB)</th><th>Free Space (GB)</th></tr>
"@

    foreach ($disk in $hardware.DiskSpace) {
        $htmlReport += "<tr><td>$($disk.DeviceID)</td><td>$($disk.'Size(GB)')</td><td>$($disk.'FreeSpace(GB)')</td></tr>"
    }

    $htmlReport += @"
        </table>
        
        <h3>Network Adapters</h3>
        <table>
            <tr><th>Name</th><th>Type</th><th>MAC Address</th></tr>
"@

    foreach ($adapter in $hardware.NetworkAdapters) {
        $htmlReport += "<tr><td>$($adapter.Name)</td><td>$($adapter.AdapterType)</td><td>$($adapter.MACAddress)</td></tr>"
    }

    $htmlReport += @"
        </table>
        
        <h2>Software Information</h2>
        <table>
            <tr><th>Name</th><th>Version</th><th>Vendor</th><th>Install Date</th></tr>
"@

    foreach ($app in $software) {
        $htmlReport += "<tr><td>$($app.Name)</td><td>$($app.Version)</td><td>$($app.Vendor)</td><td>$($app.InstallDate)</td></tr>"
    }

    $htmlReport += @"
        </table>
    </body>
    </html>
"@

    $htmlReport | Out-File -FilePath $OutputPath
    Write-Host "Report generated successfully at $OutputPath" -ForegroundColor Green
}

# Main script
if (-not (Test-AdminRights)) {
    Write-Host "Please run this script as Administrator" -ForegroundColor Red
    exit
}

# Create menu
function Show-Menu {
    Clear-Host
    Write-Host "Hardware and Software Inventory Tool" -ForegroundColor Cyan
    Write-Host "1. Generate Report for Single Computer"
    Write-Host "2. Generate Reports for All Domain Computers"
    Write-Host "3. Exit"
}

do {
    Show-Menu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" {
            $computerName = Read-Host "Enter computer name"
            $outputPath = "C:\Reports\$computerName-Inventory-$(Get-Date -Format 'yyyyMMdd').html"
            New-Item -ItemType Directory -Path "C:\Reports" -Force | Out-Null
            New-InventoryReport -ComputerName $computerName -OutputPath $outputPath
            pause
        }
        "2" {
            $computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
            New-Item -ItemType Directory -Path "C:\Reports" -Force | Out-Null
            foreach ($computer in $computers) {
                $outputPath = "C:\Reports\$computer-Inventory-$(Get-Date -Format 'yyyyMMdd').html"
                Write-Host "Processing $computer..."
                New-InventoryReport -ComputerName $computer -OutputPath $outputPath
            }
            pause
        }
    }
} while ($choice -ne "3") 