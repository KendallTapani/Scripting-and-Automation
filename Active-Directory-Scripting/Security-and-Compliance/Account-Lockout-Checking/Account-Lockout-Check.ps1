# Account Lockout Investigation Script
# This script helps identify the sources of account lockouts

# Import required modules
Import-Module ActiveDirectory

# Function to get lockout events from PDC emulator
function Get-AccountLockoutEvents {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [int]$Hours = 24
    )
    
    # Get PDC Emulator
    $pdcEmulator = (Get-ADDomain).PDCEmulator
    
    # Calculate time span
    $startTime = (Get-Date).AddHours(-$Hours)
    
    # Get user account
    $user = Get-ADUser -Identity $Username
    
    # Search for lockout events (event ID 4740) on the PDC Emulator
    $lockoutEvents = Get-WinEvent -ComputerName $pdcEmulator -FilterHashtable @{
        LogName = 'Security'
        ID = 4740
        StartTime = $startTime
    } -ErrorAction SilentlyContinue | Where-Object {
        $_.Properties[0].Value -eq $user.SamAccountName
    }
    
    # Process events
    $results = @()
    foreach ($event in $lockoutEvents) {
        $results += [PSCustomObject]@{
            Time = $event.TimeCreated
            Username = $event.Properties[0].Value
            LockedOnDC = $pdcEmulator
            SourceComputer = $event.Properties[1].Value
        }
    }
    
    return $results
}

# Function to get bad password attempts
function Get-BadPasswordAttempts {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [int]$Hours = 24
    )
    
    # Get all domain controllers
    $domainControllers = Get-ADDomainController -Filter *
    
    # Calculate time span
    $startTime = (Get-Date).AddHours(-$Hours)
    
    # Get user account
    $user = Get-ADUser -Identity $Username
    
    # Initialize results array
    $results = @()
    
    # Check each domain controller
    foreach ($dc in $domainControllers) {
        Write-Host "Checking $($dc.HostName) for bad password attempts..."
        try {
            # Get bad password events (event ID 4625)
            $badPasswordEvents = Get-WinEvent -ComputerName $dc.HostName -FilterHashtable @{
                LogName = 'Security'
                ID = 4625
                StartTime = $startTime
            } -ErrorAction SilentlyContinue | Where-Object {
                $_.Properties[5].Value -eq $user.SamAccountName
            }
            
            # Process events
            foreach ($event in $badPasswordEvents) {
                $results += [PSCustomObject]@{
                    Time = $event.TimeCreated
                    Username = $event.Properties[5].Value
                    DomainController = $dc.HostName
                    SourceWorkstation = $event.Properties[13].Value
                    SourceIP = $event.Properties[19].Value
                    LogonType = $event.Properties[10].Value
                }
            }
        }
        catch {
            Write-Warning "Error retrieving events from $($dc.HostName): $_"
        }
    }
    
    return $results
}

# Main investigation function
function Investigate-AccountLockout {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [int]$Hours = 24,
        
        [Parameter(Mandatory = $false)]
        [switch]$UnlockAccount
    )
    
    # Get current account status
    $user = Get-ADUser -Identity $Username -Properties LockedOut, AccountLockoutTime, BadPwdCount, LastBadPasswordAttempt
    
    # Display user lockout status
    Write-Host "User Lockout Information:" -ForegroundColor Green
    Write-Host "---------------------------" -ForegroundColor Green
    Write-Host "Username: $($user.SamAccountName)"
    Write-Host "Locked Out: $($user.LockedOut)"
    Write-Host "Lockout Time: $($user.AccountLockoutTime)"
    Write-Host "Bad Password Count: $($user.BadPwdCount)"
    Write-Host "Last Bad Password Attempt: $($user.LastBadPasswordAttempt)"
    Write-Host ""
    
    # Get lockout events
    Write-Host "Checking for lockout events in the past $Hours hours..." -ForegroundColor Green
    $lockoutEvents = Get-AccountLockoutEvents -Username $Username -Hours $Hours
    
    if ($lockoutEvents.Count -eq 0) {
        Write-Host "No lockout events found in the specified time period." -ForegroundColor Yellow
    }
    else {
        Write-Host "Lockout Events:" -ForegroundColor Green
        $lockoutEvents | Format-Table -AutoSize
    }
    
    # Get bad password attempts
    Write-Host "Checking for bad password attempts in the past $Hours hours..." -ForegroundColor Green
    $badPasswordAttempts = Get-BadPasswordAttempts -Username $Username -Hours $Hours
    
    if ($badPasswordAttempts.Count -eq 0) {
        Write-Host "No bad password attempts found in the specified time period." -ForegroundColor Yellow
    }
    else {
        Write-Host "Bad Password Attempts:" -ForegroundColor Green
        $badPasswordAttempts | Format-Table -AutoSize
    }
    
    # Unlock account if requested
    if ($UnlockAccount -and $user.LockedOut) {
        Write-Host "Unlocking account for $Username..." -ForegroundColor Yellow
        Unlock-ADAccount -Identity $Username
        Write-Host "Account unlocked successfully." -ForegroundColor Green
    }
    
    # Export results
    $outputPath = "C:\Reports\LockoutInvestigation_$($Username)_$(Get-Date -Format 'yyyy-MM-dd-HHmmss').csv"
    $outputDir = Split-Path -Path $outputPath -Parent
    if (-not (Test-Path -Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force
    }
    
    $combinedResults = $lockoutEvents + $badPasswordAttempts
    if ($combinedResults.Count -gt 0) {
        $combinedResults | Export-Csv -Path $outputPath -NoTypeInformation
        Write-Host "Investigation report saved to $outputPath" -ForegroundColor Green
    }
}

# Example usage:
# Investigate-AccountLockout -Username "john.doe" -Hours 48 -UnlockAccount
