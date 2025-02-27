# Stale Computer Account Identification and Cleanup
# This script identifies computer accounts that haven't contacted the domain in X days
# and either reports on them or removes them based on parameters

# Parameters
param(
    [Parameter(Mandatory=$false)]
    [int]$InactiveDays = 90, # Default to 90 days
    
    [Parameter(Mandatory=$false)]
    [switch]$ReportOnly = $true, # Default to report only (no deletion)
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\Reports\StaleComputers_$(Get-Date -Format 'yyyyMMdd').csv",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\StaleComputerCleanup_$(Get-Date -Format 'yyyyMMdd').log"
)

# Import required modules
Import-Module ActiveDirectory

# Start logging
Start-Transcript -Path $LogPath -Append
Write-Output "Script started at $(Get-Date)"
Write-Output "Looking for computers inactive for more than $InactiveDays days"

# Get the date threshold for inactivity
$InactiveDate = (Get-Date).AddDays(-$InactiveDays)

# Get all computer accounts
Write-Output "Retrieving all computer accounts from Active Directory..."
$AllComputers = Get-ADComputer -Filter * -Properties Name, LastLogonDate, OperatingSystem, Description, DistinguishedName

# Identify stale computers
Write-Output "Identifying stale computer accounts..."
$StaleComputers = $AllComputers | Where-Object { 
    $_.LastLogonDate -lt $InactiveDate -or $_.LastLogonDate -eq $null 
}

# Output statistics
Write-Output "Total computers found: $($AllComputers.Count)"
Write-Output "Stale computers found: $($StaleComputers.Count)"

# Export the report of stale computers
if ($StaleComputers.Count -gt 0) {
    # Create the directory for the report if it doesn't exist
    $ReportDirectory = Split-Path -Path $ReportPath -Parent
    if (-not (Test-Path -Path $ReportDirectory)) {
        New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null
    }

    Write-Output "Exporting stale computer report to $ReportPath"
    $StaleComputers | Select-Object Name, LastLogonDate, OperatingSystem, Description, DistinguishedName |
        Export-Csv -Path $ReportPath -NoTypeInformation
    
    # If not in report-only mode, remove the stale computers
    if (-not $ReportOnly) {
        Write-Output "Removing stale computer accounts..."
        foreach ($Computer in $StaleComputers) {
            try {
                Remove-ADComputer -Identity $Computer.DistinguishedName -Confirm:$false
                Write-Output "Removed computer: $($Computer.Name)"
            }
            catch {
                Write-Error "Failed to remove computer $($Computer.Name): $_"
            }
        }
        Write-Output "Stale computer removal complete."
    }
    else {
        Write-Output "Report-only mode enabled. No computers were removed."
        Write-Output "Review $ReportPath and run again with -ReportOnly:`$false to remove these computers."
    }
}
else {
    Write-Output "No stale computers found. No action taken."
}

Write-Output "Script completed at $(Get-Date)"
Stop-Transcript

# Examples of how to use this script:
# 
# 1. Report Only Mode (default)
# .\StaleComputerCleanup.ps1
# 
# 2. Report with custom inactive days threshold
# .\StaleComputerCleanup.ps1 -InactiveDays 120
# 
# 3. Cleanup Mode (will delete stale accounts)
# .\StaleComputerCleanup.ps1 -ReportOnly:$false
# 
# 4. Custom paths for reports and logs
# .\StaleComputerCleanup.ps1 -ReportPath "D:\Reports\Stale.csv" -LogPath "D:\Logs\Cleanup.log"
