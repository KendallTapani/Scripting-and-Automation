# Import AD Module
Import-Module ActiveDirectory

# Function to lock a user account
function Lock-UserAccount {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        
        [Parameter(Mandatory=$false)]
        [string]$Reason = "Administrative lock"
    )
    
    try {
        # Disable the account
        Disable-ADAccount -Identity $Username
        
        # Add a description to indicate why the account was locked
        Set-ADUser -Identity $Username -Description "LOCKED: $Reason - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        
        Write-Host "Account for user $Username has been locked." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Error locking account for $($Username): $_" -ForegroundColor Red
    }
}

# Function to unlock a user account
function Unlock-UserAccount {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username
    )
    
    try {
        # Enable the account
        Enable-ADAccount -Identity $Username
        
        # Clear the description or update it to show it was unlocked
        $CurrentDesc = (Get-ADUser -Identity $Username -Properties Description).Description
        if ($CurrentDesc -match "^LOCKED:") {
            Set-ADUser -Identity $Username -Description "UNLOCKED: $(Get-Date -Format 'yyyy-MM-dd HH:mm') - Previously: $CurrentDesc"
        }
        
        Write-Host "Account for user $Username has been unlocked." -ForegroundColor Green
    }
    catch {
        Write-Host "Error unlocking account for $($Username): $_" -ForegroundColor Red
    }
}

# Function to handle bulk account locking/unlocking from a CSV file
function Process-BulkAccountStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CSVPath
    )
    
    try {
        # Import CSV file (format: Username,Action,Reason)
        # Where Action is either "Lock" or "Unlock"
        $Users = Import-Csv -Path $CSVPath
        
        foreach ($User in $Users) {
            if ($User.Action -eq "Lock") {
                Lock-UserAccount -Username $User.Username -Reason $User.Reason
            }
            elseif ($User.Action -eq "Unlock") {
                Unlock-UserAccount -Username $User.Username
            }
            else {
                Write-Host "Invalid action '$($User.Action)' for user $($User.Username)" -ForegroundColor Red
            }
        }
        
        Write-Host "Bulk account processing completed." -ForegroundColor Green
    }
    catch {
        Write-Host "Error processing CSV file: $_" -ForegroundColor Red
    }
}

# Function to get all locked accounts in the domain
function Get-LockedAccounts {
    try {
        $LockedAccounts = Search-ADAccount -LockedOut
        
        if ($LockedAccounts.Count -eq 0) {
            Write-Host "No locked accounts found." -ForegroundColor Green
        }
        else {
            Write-Host "Found $($LockedAccounts.Count) locked account(s):" -ForegroundColor Yellow
            $LockedAccounts | Select-Object Name, SamAccountName, DistinguishedName | Format-Table -AutoSize
        }
        
        return $LockedAccounts
    }
    catch {
        Write-Host "Error retrieving locked accounts: $_" -ForegroundColor Red
    }
}

# Example usage:
# Lock-UserAccount -Username "john.doe" -Reason "Suspicious activity"
# Unlock-UserAccount -Username "john.doe"
# Process-BulkAccountStatus -CSVPath "C:\Scripts\account_actions.csv"
# Get-LockedAccounts
