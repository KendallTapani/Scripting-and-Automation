# Import necessary modules
Import-Module ActiveDirectory

# Function to generate a random password
function New-RandomPassword {
    param (
        [int]$Length = 12,
        [int]$SpecialChars = 2,
        [int]$Digits = 2
    )
    
    # Define character sets
    $Lowercase = 'abcdefghijklmnopqrstuvwxyz'
    $Uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $Numbers = '0123456789'
    $Special = '!@#$%^&*()-_=+[]{}|;:,.<>?'
    
    # Start with required number of random special characters
    $Password = ''
    for ($i = 0; $i -lt $SpecialChars; $i++) {
        $Password += $Special[(Get-Random -Maximum $Special.Length)]
    }
    
    # Add required number of random digits
    for ($i = 0; $i -lt $Digits; $i++) {
        $Password += $Numbers[(Get-Random -Maximum $Numbers.Length)]
    }
    
    # Fill the rest with random uppercase and lowercase letters
    $RemainingLength = $Length - $SpecialChars - $Digits
    for ($i = 0; $i -lt $RemainingLength; $i++) {
        if (Get-Random -Maximum 2) {
            $Password += $Uppercase[(Get-Random -Maximum $Uppercase.Length)]
        } else {
            $Password += $Lowercase[(Get-Random -Maximum $Lowercase.Length)]
        }
    }
    
    # Shuffle the password characters
    $Password = -join ($Password.ToCharArray() | Get-Random -Count $Password.Length)
    
    return $Password
}

# Function to log actions to a file
function Write-ActionLog {
    param (
        [string]$Action,
        [string]$Username,
        [string]$PerformedBy,
        [string]$Details = "",
        [string]$LogFile = "C:\Logs\AD_Actions.log"
    )
    
    # Create directory if it doesn't exist
    $LogDir = Split-Path -Path $LogFile -Parent
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    # Format log entry
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp,$Action,$Username,$PerformedBy,$Details"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogEntry
}

# Function to validate user exists in AD
function Test-ADUser {
    param (
        [string]$Username
    )
    
    try {
        $User = Get-ADUser -Identity $Username
        return $true
    }
    catch {
        return $false
    }
}

# Function to validate current user has appropriate permissions
function Test-AdminRights {
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object System.Security.Principal.WindowsPrincipal($CurrentUser)
    $AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    
    return $Principal.IsInRole($AdminRole)
}

# Function to reset a user's password with logging
function Reset-ADUserPasswordSecure {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Username,
        
        [Parameter(Mandatory=$false)]
        [string]$NewPassword = "",
        
        [Parameter(Mandatory=$false)]
        [bool]$GenerateRandom = $true,
        
        [Parameter(Mandatory=$false)]
        [bool]$MustChangePasswordAtLogon = $true,
        
        [Parameter(Mandatory=$false)]
        [int]$PasswordLength = 12
    )
    
    # Verify the user exists
    if (-not (Test-ADUser -Username $Username)) {
        Write-Host "User '$Username' does not exist in Active Directory." -ForegroundColor Red
        return $null
    }
    
    # Generate random password if requested or if no password provided
    if ($GenerateRandom -or [string]::IsNullOrEmpty($NewPassword)) {
        $NewPassword = New-RandomPassword -Length $PasswordLength
    }
    
    try {
        # Convert password to secure string
        $SecurePassword = ConvertTo-SecureString -String $NewPassword -AsPlainText -Force
        
        # Reset the password
        Set-ADAccountPassword -Identity $Username -NewPassword $SecurePassword -Reset
        
        # Require password change at next logon if specified
        if ($MustChangePasswordAtLogon) {
            Set-ADUser -Identity $Username -ChangePasswordAtLogon $true
        }
        
        # Unlock the account in case it was locked
        Unlock-ADAccount -Identity $Username
        
        # Log the action
        $CurrentUser = $env:USERNAME
        Write-ActionLog -Action "PasswordReset" -Username $Username -PerformedBy $CurrentUser -Details "Change at logon: $MustChangePasswordAtLogon"
        
        Write-Host "Password for user '$Username' has been reset successfully." -ForegroundColor Green
        
        # Return the new password for temporary display
        return $NewPassword
    }
    catch {
        Write-Host "Error resetting password for user '$Username': $_" -ForegroundColor Red
        return $null
    }
}

# Function to manage account locking/unlocking with logging
function Set-ADAccountStatus {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Username,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Lock", "Unlock")]
        [string]$Action,
        
        [Parameter(Mandatory=$false)]
        [string]$Reason = "Administrative action"
    )
    
    # Verify the user exists
    if (-not (Test-ADUser -Username $Username)) {
        Write-Host "User '$Username' does not exist in Active Directory." -ForegroundColor Red
        return
    }
    
    try {
        $CurrentUser = $env:USERNAME
        
        if ($Action -eq "Lock") {
            # Disable the account
            Disable-ADAccount -Identity $Username
            
            # Add a description to indicate why the account was locked
            Set-ADUser -Identity $Username -Description "LOCKED: $Reason - $(Get-Date -Format 'yyyy-MM-dd HH:mm') by $CurrentUser"
            
            # Log the action
            Write-ActionLog -Action "AccountLocked" -Username $Username -PerformedBy $CurrentUser -Details $Reason
            
            Write-Host "Account for user '$Username' has been locked." -ForegroundColor Yellow
        }
        else {
            # Enable the account
            Enable-ADAccount -Identity $Username
            
            # Clear the description or update it to show it was unlocked
            $CurrentDesc = (Get-ADUser -Identity $Username -Properties Description).Description
            if ($CurrentDesc -match "^LOCKED:") {
                Set-ADUser -Identity $Username -Description "UNLOCKED: $(Get-Date -Format 'yyyy-MM-dd HH:mm') by $CurrentUser - Previously: $CurrentDesc"
            }
            
            # Log the action
            Write-ActionLog -Action "AccountUnlocked" -Username $Username -PerformedBy $CurrentUser
            
            Write-Host "Account for user '$Username' has been unlocked." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error managing account status for user '$Username': $_" -ForegroundColor Red
    }
}

# Function to display a simple text-based menu
function Show-Menu {
    param (
        [string]$Title = "AD Account Management Tool"
    )
    
    Clear-Host
    Write-Host "===== $Title =====" -ForegroundColor Cyan
    Write-Host "1: Reset User Password"
    Write-Host "2: Lock User Account"
    Write-Host "3: Unlock User Account"
    Write-Host "4: View Locked Accounts"
    Write-Host "5: Bulk Process from CSV"
    Write-Host "Q: Quit"
    Write-Host "=====================" -ForegroundColor Cyan
}

# Main script for interactive use
function Start-ADAccountTools {
    # Verify admin rights
    if (-not (Test-AdminRights)) {
        Write-Host "This script requires administrative privileges. Please run as administrator." -ForegroundColor Red
        return
    }
    
    # Main menu loop
    do {
        Show-Menu
        $Selection = Read-Host "Please make a selection"
        
        switch ($Selection) {
            '1' {
                $Username = Read-Host "Enter username to reset password"
                $GenerateRandom = $true
                
                $GenOption = Read-Host "Generate random password? (Y/N, default Y)"
                if ($GenOption -eq "N" -or $GenOption -eq "n") {
                    $NewPassword = Read-Host "Enter new password" -AsSecureString
                    $GenerateRandom = $false
                    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword))
                }
                
                $MustChange = $true
                $ChangeOption = Read-Host "Require password change at next logon? (Y/N, default Y)"
                if ($ChangeOption -eq "N" -or $ChangeOption -eq "n") {
                    $MustChange = $false
                }
                
                if ($GenerateRandom) {
                    $Password = Reset-ADUserPasswordSecure -Username $Username -GenerateRandom $true -MustChangePasswordAtLogon $MustChange
                    if ($Password) {
                        Write-Host "New password: $Password" -ForegroundColor Yellow
                        Write-Host "IMPORTANT: Note this password before continuing." -ForegroundColor Red
                        Read-Host "Press Enter to continue"
                    }
                }
                else {
                    Reset-ADUserPasswordSecure -Username $Username -NewPassword $PlainPassword -GenerateRandom $false -MustChangePasswordAtLogon $MustChange
                }
            }
            '2' {
                $Username = Read-Host "Enter username to lock"
                $Reason = Read-Host "Enter reason for locking account"
                Set-ADAccountStatus -Username $Username -Action "Lock" -Reason $Reason
                Read-Host "Press Enter to continue"
            }
            '3' {
                $Username = Read-Host "Enter username to unlock"
                Set-ADAccountStatus -Username $Username -Action "Unlock"
                Read-Host "Press Enter to continue"
            }
            '4' {
                $LockedAccounts = Search-ADAccount -LockedOut
                
                if ($LockedAccounts.Count -eq 0) {
                    Write-Host "No locked accounts found." -ForegroundColor Green
                }
                else {
                    Write-Host "Found $($LockedAccounts.Count) locked account(s):" -ForegroundColor Yellow
                    $LockedAccounts | Select-Object Name, SamAccountName, DistinguishedName | Format-Table -AutoSize
                    
                    $UnlockOption = Read-Host "Would you like to unlock any of these accounts? (Y/N)"
                    if ($UnlockOption -eq "Y" -or $UnlockOption -eq "y") {
                        $UnlockUser = Read-Host "Enter username to unlock"
                        Set-ADAccountStatus -Username $UnlockUser -Action "Unlock"
                    }
                }
                
                Read-Host "Press Enter to continue"
            }
            '5' {
                $CSVPath = Read-Host "Enter path to CSV file"
                
                if (Test-Path -Path $CSVPath) {
                    $CSVType = Read-Host "What type of CSV? (1: Password Resets, 2: Account Status)"
                    
                    if ($CSVType -eq "1") {
                        # Process password resets
                        try {
                            $Users = Import-Csv -Path $CSVPath
                            foreach ($User in $Users) {
                                $MustChange = if ($User.MustChangePasswordAtLogon -eq "True") { $true } else { $false }
                                
                                if ([string]::IsNullOrEmpty($User.NewPassword)) {
                                    $Password = Reset-ADUserPasswordSecure -Username $User.Username -GenerateRandom $true -MustChangePasswordAtLogon $MustChange
                                    Write-Host "User: $($User.Username) - New password: $Password" -ForegroundColor Yellow
                                }
                                else {
                                    Reset-ADUserPasswordSecure -Username $User.Username -NewPassword $User.NewPassword -GenerateRandom $false -MustChangePasswordAtLogon $MustChange
                                }
                            }
                        }
                        catch {
                            Write-Host "Error processing CSV file: $_" -ForegroundColor Red
                        }
                    }
                    elseif ($CSVType -eq "2") {
                        # Process account status changes
                        try {
                            $Users = Import-Csv -Path $CSVPath
                            foreach ($User in $Users) {
                                if ($User.Action -eq "Lock" -or $User.Action -eq "Unlock") {
                                    Set-ADAccountStatus -Username $User.Username -Action $User.Action -Reason $User.Reason
                                }
                                else {
                                    Write-Host "Invalid action '$($User.Action)' for user $($User.Username)" -ForegroundColor Red
                                }
                            }
                        }
                        catch {
                            Write-Host "Error processing CSV file: $_" -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Invalid selection." -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "File not found: $CSVPath" -ForegroundColor Red
                }
                
                Read-Host "Press Enter to continue"
            }
        }
    } while ($Selection -ne 'Q' -and $Selection -ne 'q')
}

# Example usage:
# Start-ADAccountTools
