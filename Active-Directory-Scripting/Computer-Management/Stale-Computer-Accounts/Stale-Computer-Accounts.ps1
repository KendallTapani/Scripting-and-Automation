# Stale Computer Accounts Management Script
# This script identifies and manages stale computer accounts in Active Directory

# Import required module
Import-Module ActiveDirectory

# Function to validate admin rights
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to get stale computer accounts
function Get-StaleComputers {
    param (
        [Parameter(Mandatory=$true)]
        [int]$DaysInactive
    )
    
    $cutoffDate = (Get-Date).AddDays(-$DaysInactive)
    $staleComputers = Get-ADComputer -Filter {LastLogonTimeStamp -lt $cutoffDate} -Properties Name, LastLogonTimeStamp, OperatingSystem, Description |
        Select-Object Name, 
            @{N='LastLogon';E={[DateTime]::FromFileTime($_.LastLogonTimeStamp)}},
            OperatingSystem,
            Description,
            DistinguishedName
    
    return $staleComputers
}

# Function to disable computer account
function Disable-StaleComputer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        Disable-ADAccount -Identity $ComputerName
        Write-Host "Successfully disabled computer account: $ComputerName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error disabling computer account $ComputerName`: $_" -ForegroundColor Red
        return $false
    }
}

# Function to move computer to stale computers OU
function Move-ToStaleOU {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    $staleOU = "OU=Stale Computers,DC=kendalltapani,DC=com"
    
    try {
        # Create Stale Computers OU if it doesn't exist
        if (-not (Get-ADOrganizationalUnit -Filter {Name -eq "Stale Computers"})) {
            New-ADOrganizationalUnit -Name "Stale Computers" -Path "DC=kendalltapani,DC=com"
        }
        
        # Move computer to Stale Computers OU
        $computer = Get-ADComputer -Identity $ComputerName
        Move-ADObject -Identity $computer.DistinguishedName -TargetPath $staleOU
        Write-Host "Successfully moved $ComputerName to Stale Computers OU" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error moving computer $ComputerName`: $_" -ForegroundColor Red
        return $false
    }
}

# Function to delete computer account
function Remove-StaleComputer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        Remove-ADComputer -Identity $ComputerName -Confirm:$false
        Write-Host "Successfully deleted computer account: $ComputerName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error deleting computer account $ComputerName`: $_" -ForegroundColor Red
        return $false
    }
}

# Function to export stale computer report
function Export-StaleReport {
    param (
        [Parameter(Mandatory=$true)]
        [array]$StaleComputers,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    try {
        $StaleComputers | Export-Csv -Path $OutputPath -NoTypeInformation
        Write-Host "Successfully exported stale computer report to: $OutputPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error exporting report: $_" -ForegroundColor Red
        return $false
    }
}

# Main script
if (-not (Test-AdminRights)) {
    Write-Host "Please run this script as Administrator" -ForegroundColor Red
    exit
}

# Create menu
function Show-Menu {
    Clear-Host
    Write-Host "Stale Computer Account Management Tool" -ForegroundColor Cyan
    Write-Host "1. View Stale Computer Accounts"
    Write-Host "2. Disable Stale Accounts"
    Write-Host "3. Move Stale Accounts to Separate OU"
    Write-Host "4. Delete Stale Accounts"
    Write-Host "5. Export Stale Account Report"
    Write-Host "6. Exit"
}

do {
    Show-Menu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" {
            $days = Read-Host "Enter number of days inactive (default: 90)"
            if ([string]::IsNullOrEmpty($days)) { $days = 90 }
            
            $staleComputers = Get-StaleComputers -DaysInactive $days
            Write-Host "`nFound $($staleComputers.Count) stale computer accounts:" -ForegroundColor Yellow
            $staleComputers | Format-Table -AutoSize
            pause
        }
        "2" {
            $days = Read-Host "Enter number of days inactive (default: 90)"
            if ([string]::IsNullOrEmpty($days)) { $days = 90 }
            
            $staleComputers = Get-StaleComputers -DaysInactive $days
            Write-Host "`nDisabling $($staleComputers.Count) stale computer accounts..." -ForegroundColor Yellow
            
            foreach ($computer in $staleComputers) {
                Disable-StaleComputer -ComputerName $computer.Name
            }
            pause
        }
        "3" {
            $days = Read-Host "Enter number of days inactive (default: 90)"
            if ([string]::IsNullOrEmpty($days)) { $days = 90 }
            
            $staleComputers = Get-StaleComputers -DaysInactive $days
            Write-Host "`nMoving $($staleComputers.Count) stale computer accounts..." -ForegroundColor Yellow
            
            foreach ($computer in $staleComputers) {
                Move-ToStaleOU -ComputerName $computer.Name
            }
            pause
        }
        "4" {
            $days = Read-Host "Enter number of days inactive (default: 90)"
            if ([string]::IsNullOrEmpty($days)) { $days = 90 }
            
            $confirmation = Read-Host "Are you sure you want to delete stale computer accounts? (Y/N)"
            if ($confirmation -eq "Y") {
                $staleComputers = Get-StaleComputers -DaysInactive $days
                Write-Host "`nDeleting $($staleComputers.Count) stale computer accounts..." -ForegroundColor Yellow
                
                foreach ($computer in $staleComputers) {
                    Remove-StaleComputer -ComputerName $computer.Name
                }
            }
            pause
        }
        "5" {
            $days = Read-Host "Enter number of days inactive (default: 90)"
            if ([string]::IsNullOrEmpty($days)) { $days = 90 }
            
            $staleComputers = Get-StaleComputers -DaysInactive $days
            $outputPath = "C:\Reports\StaleComputers-$(Get-Date -Format 'yyyyMMdd').csv"
            New-Item -ItemType Directory -Path "C:\Reports" -Force | Out-Null
            
            Export-StaleReport -StaleComputers $staleComputers -OutputPath $outputPath
            pause
        }
    }
} while ($choice -ne "6") 