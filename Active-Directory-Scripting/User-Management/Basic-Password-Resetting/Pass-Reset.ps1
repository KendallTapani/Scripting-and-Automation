# Import AD Module
Import-Module ActiveDirectory

# Function to reset a single user's password
function Reset-UserPassword {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        
        [Parameter(Mandatory=$true)]
        [string]$NewPassword,
        
        [Parameter(Mandatory=$false)]
        [bool]$MustChangePasswordAtLogon = $true
    )
    
    try {
        # Convert the password to a secure string
        $SecurePassword = ConvertTo-SecureString -String $NewPassword -AsPlainText -Force
        
        # Reset the password
        Set-ADAccountPassword -Identity $Username -NewPassword $SecurePassword -Reset
        
        # If MustChangePasswordAtLogon is true, force user to change password at next logon
        if ($MustChangePasswordAtLogon) {
            Set-ADUser -Identity $Username -ChangePasswordAtLogon $true
        }
        
        Write-Host "Password for user $Username has been reset successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Error resetting password for $($Username): $_" -ForegroundColor Red
    }
}

# Function to reset passwords for multiple users from a CSV file
function Reset-BulkPasswords {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CSVPath
    )
    
    try {
        # Import CSV file (format: Username,NewPassword,MustChangePasswordAtLogon)
        $Users = Import-Csv -Path $CSVPath
        
        foreach ($User in $Users) {
            $MustChange = if ($User.MustChangePasswordAtLogon -eq "True") { $true } else { $false }
            Reset-UserPassword -Username $User.Username -NewPassword $User.NewPassword -MustChangePasswordAtLogon $MustChange
        }
        
        Write-Host "Bulk password reset completed." -ForegroundColor Green
    }
    catch {
        Write-Host "Error processing CSV file: $_" -ForegroundColor Red
    }
}

# Example usage:
# Reset-UserPassword -Username "john.doe" -NewPassword "P@ssw0rd123!" -MustChangePasswordAtLogon $true
# Reset-BulkPasswords -CSVPath "C:\Scripts\users_to_reset.csv"