# Computer OU Organization Script
# This script helps organize computer accounts into appropriate OUs based on criteria like department, location, or function

# Function to validate admin rights
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
        $computer = Get-ADComputer -Identity $ComputerName
        Move-ADObject -Identity $computer.DistinguishedName -TargetPath $TargetOU
        Write-Host "Successfully moved $ComputerName to $TargetOU" -ForegroundColor Green
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

# Define OUs
$ouStructure = @{
    "Workstations" = "OU=Workstations,DC=kendalltapani,DC=com"
    "Servers" = "OU=Servers,DC=kendalltapani,DC=com"
    "Legacy" = "OU=Legacy,DC=kendalltapani,DC=com"
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
            Write-Host "Available OUs:"
            $ouStructure.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): $($_.Value)" }
            $targetOU = Read-Host "Enter target OU path"
            Move-ComputerToOU -ComputerName $computerName -TargetOU $targetOU
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
            $ouPath = Read-Host "Enter parent OU path (e.g., DC=kendalltapani,DC=com)"
            try {
                New-ADOrganizationalUnit -Name $ouName -Path $ouPath
                $ouStructure[$ouName] = "OU=$ouName,$ouPath"
                Write-Host "OU created successfully" -ForegroundColor Green
            }
            catch {
                Write-Host ("Error creating OU: {0}" -f $_.Exception.Message) -ForegroundColor Red
            }
            pause
        }
    }
} while ($choice -ne "5") 