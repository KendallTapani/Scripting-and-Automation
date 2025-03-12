# Computer OU Organization Script
# This script helps organize computer accounts into appropriate OUs based on criteria like department, location, or function

# Import required module
Import-Module ActiveDirectory

# Function to validate admin rights
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to verify OU exists
function Test-OUExists {
    param (
        [Parameter(Mandatory=$true)]
        [string]$OUPath
    )
    try {
        $null = Get-ADOrganizationalUnit -Identity $OUPath
        return $true
    }
    catch {
        return $false
    }
}

# Function to create OU if it doesn't exist
function New-OUIfNotExists {
    param (
        [Parameter(Mandatory=$true)]
        [string]$OUName,
        [Parameter(Mandatory=$true)]
        [string]$ParentPath
    )
    
    $ouPath = "OU=$OUName,$ParentPath"
    if (-not (Test-OUExists -OUPath $ouPath)) {
        try {
            New-ADOrganizationalUnit -Name $OUName -Path $ParentPath
            Write-Host ("Created OU: {0}" -f $ouPath) -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host ("Error creating OU {0}: {1}" -f $OUName, $_.Exception.Message) -ForegroundColor Red
            return $false
        }
    }
    return $true
}

# Function to get all computers and their properties
function Get-ComputerProperties {
    Get-ADComputer -Filter * -Properties Name, Description, OperatingSystem, Created, LastLogonDate |
    Select-Object Name, Description, OperatingSystem, Created, LastLogonDate, DistinguishedName
}

# Function to move computer to appropriate OU
function Move-ComputerToOU {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$true)]
        [string]$TargetOU
    )
    try {
        # First verify the computer exists
        $computer = Get-ADComputer -Identity $ComputerName
        if (-not $computer) {
            Write-Host ("Computer {0} not found" -f $ComputerName) -ForegroundColor Red
            return
        }

        # Verify target OU exists
        if (-not (Test-OUExists -OUPath $TargetOU)) {
            Write-Host ("Target OU {0} does not exist" -f $TargetOU) -ForegroundColor Red
            return
        }

        # Move the computer
        Move-ADObject -Identity $computer.DistinguishedName -TargetPath $TargetOU
        Write-Host ("Successfully moved {0} to {1}" -f $ComputerName, $TargetOU) -ForegroundColor Green
    }
    catch {
        Write-Host ("Error moving {0}: {1}" -f $ComputerName, $_.Exception.Message) -ForegroundColor Red
    }
}

# Main script
if (-not (Test-AdminRights)) {
    Write-Host "Please run this script as Administrator" -ForegroundColor Red
    exit
}

# Define domain
$domainDN = (Get-ADDomain).DistinguishedName

# Define OUs and ensure they exist
$ouStructure = @{
    "Workstations" = "OU=Workstations,$domainDN"
    "Servers" = "OU=Servers,$domainDN"
    "Legacy" = "OU=Legacy,$domainDN"
}

# Create base OUs if they don't exist
foreach ($ou in $ouStructure.GetEnumerator()) {
    New-OUIfNotExists -OUName $ou.Key -ParentPath $domainDN
}

# Create menu
function Show-Menu {
    Clear-Host
    Write-Host "Computer OU Organization Tool" -ForegroundColor Cyan
    Write-Host "1. View Current Computer Organization"
    Write-Host "2. Move Computer to Different OU"
    Write-Host "3. Bulk Move Computers Based on OS"
    Write-Host "4. Create New OU"
    Write-Host "5. Exit"
}

do {
    Show-Menu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" {
            Write-Host "`nCurrent Computer Organization:" -ForegroundColor Cyan
            Get-ComputerProperties | Format-Table -AutoSize
            pause
        }
        "2" {
            $computerName = Read-Host "Enter computer name"
            Write-Host "`nAvailable OUs:"
            $ouStructure.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): $($_.Value)" }
            $targetOUKey = Read-Host "`nEnter OU name (e.g., Workstations, Servers, Legacy)"
            
            if ($ouStructure.ContainsKey($targetOUKey)) {
                $targetOU = $ouStructure[$targetOUKey]
                Move-ComputerToOU -ComputerName $computerName -TargetOU $targetOU
            }
            else {
                Write-Host "Invalid OU selection. Please choose from the available OUs." -ForegroundColor Red
            }
            pause
        }
        "3" {
            Write-Host "Moving computers based on OS type..."
            $computers = Get-ComputerProperties
            foreach ($computer in $computers) {
                if ($computer.OperatingSystem -like "*Server*") {
                    Move-ComputerToOU -ComputerName $computer.Name -TargetOU $ouStructure["Servers"]
                }
                elseif ($computer.OperatingSystem -like "*Windows 10*" -or $computer.OperatingSystem -like "*Windows 11*") {
                    Move-ComputerToOU -ComputerName $computer.Name -TargetOU $ouStructure["Workstations"]
                }
                else {
                    Move-ComputerToOU -ComputerName $computer.Name -TargetOU $ouStructure["Legacy"]
                }
            }
            pause
        }
        "4" {
            $ouName = Read-Host "Enter new OU name"
            Write-Host "`nCurrent domain path: $domainDN"
            $createOU = New-OUIfNotExists -OUName $ouName -ParentPath $domainDN
            if ($createOU) {
                $ouStructure[$ouName] = "OU=$ouName,$domainDN"
            }
            pause
        }
    }
} while ($choice -ne "5") 