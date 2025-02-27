# Script to identify and disable inactive Active Directory user accounts
# Requirements: Active Directory PowerShell module, admin rights

# Import the Active Directory module
Import-Module ActiveDirectory

# Parameters - customize these values
$InactiveDays = 90                   # Number of days of inactivity to consider an account inactive
$DisableInactiveAccounts = $true     # Set to $false for report-only mode without disabling
$LogPath = "C:\Logs\InactiveUsers_$(Get-Date -Format 'yyyyMMdd').csv" # Path to save the log file
$ExcludedOUs = @(                    # OUs to exclude from checking (Distinguished Names)
    "OU=Service Accounts,DC=contoso,DC=com",
    "OU=Admins,DC=contoso,DC=com"
)
$ExcludedUsers = @(                  # Specific users to exclude (samAccountNames)
    "Administrator",
    "Guest",
    "krbtgt"
)

# Create log directory if it doesn't exist
$LogDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path -Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory | Out-Null
}

# Calculate the cutoff date for inactivity
$CutoffDate = (Get-Date).AddDays(-$InactiveDays)
Write-Host "Identifying accounts inactive since $CutoffDate" -ForegroundColor Cyan

# Initialize results array
$InactiveUsers = @()

# Get all user accounts
$AllUsers = Get-ADUser -Filter * -Properties LastLogonTimestamp, Enabled, Description, DistinguishedName, whenCreated

Write-Host "Found $($AllUsers.Count) total user accounts in Active Directory" -ForegroundColor Cyan

# Process each user
foreach ($User in $AllUsers) {
    # Skip excluded users and OUs
    if ($ExcludedUsers -contains $User.SamAccountName) { continue }
    if ($ExcludedOUs | Where-Object { $User.DistinguishedName -like "*$_*" }) { continue }
    
    # Skip already disabled accounts
    if (-not $User.Enabled) { continue }
    
    # Convert LastLogonTimestamp to a date (if it exists)
    if ($User.LastLogonTimestamp) {
        $LastLogon = [DateTime]::FromFileTime($User.LastLogonTimestamp)
    }
    else {
        # If LastLogonTimestamp is empty, use account creation date
        $LastLogon = $User.whenCreated
    }
    
    # Check if the account is inactive
    if ($LastLogon -lt $CutoffDate) {
        $InactiveUsers += [PSCustomObject]@{
            SamAccountName = $User.SamAccountName
            Name = $User.Name
            LastLogon = $LastLogon
            DaysSinceLastLogon = (New-TimeSpan -Start $LastLogon -End (Get-Date)).Days
            DistinguishedName = $User.DistinguishedName
            WhenCreated = $User.whenCreated
            WasDisabled = $false
        }
    }
}

Write-Host "Found $($InactiveUsers.Count) inactive user accounts" -ForegroundColor Yellow

# Disable inactive accounts if configured to do so
if ($DisableInactiveAccounts -and $InactiveUsers.Count -gt 0) {
    Write-Host "Disabling inactive accounts..." -ForegroundColor Yellow
    
    foreach ($InactiveUser in $InactiveUsers) {
        try {
            # Get current description
            $CurrentUser = Get-ADUser -Identity $InactiveUser.SamAccountName -Properties Description
            $CurrentDescription = $CurrentUser.Description
            
            # Append to description or create new one
            $NewDescription = if ($CurrentDescription) {
                "$CurrentDescription | DISABLED (Inactive for $($InactiveUser.DaysSinceLastLogon) days) on $(Get-Date -Format 'yyyy-MM-dd')"
            }
            else {
                "DISABLED (Inactive for $($InactiveUser.DaysSinceLastLogon) days) on $(Get-Date -Format 'yyyy-MM-dd')"
            }
            
            # Disable the account and update description
            Disable-ADAccount -Identity $InactiveUser.SamAccountName
            Set-ADUser -Identity $InactiveUser.SamAccountName -Description $NewDescription
            
            # Update the status in our results
            $InactiveUser.WasDisabled = $true
            
            Write-Host "  Disabled: $($InactiveUser.Name) ($($InactiveUser.SamAccountName))" -ForegroundColor Gray
        }
        catch {
            Write-Host "  Error disabling $($InactiveUser.Name): $_" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "Running in report-only mode - no accounts will be disabled" -ForegroundColor Cyan
}

# Export results to CSV
$InactiveUsers | Export-Csv -Path $LogPath -NoTypeInformation

# Output summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total user accounts: $($AllUsers.Count)" -ForegroundColor White
Write-Host "Inactive accounts: $($InactiveUsers.Count)" -ForegroundColor Yellow
if ($DisableInactiveAccounts) {
    $DisabledCount = ($InactiveUsers | Where-Object { $_.WasDisabled -eq $true }).Count
    Write-Host "Accounts disabled: $DisabledCount" -ForegroundColor Yellow
}
Write-Host "Report saved to: $LogPath" -ForegroundColor Green