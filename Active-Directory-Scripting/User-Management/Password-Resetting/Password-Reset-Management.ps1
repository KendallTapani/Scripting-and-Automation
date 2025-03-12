# Schedule Password Reset Script for kendalltapani.com
$domain = "kendalltapani.com"
$maxPasswordAge = 90

function Show-Menu {
    Clear-Host
    Write-Host "=== Password Reset Scheduling Tool ===" -ForegroundColor Cyan
    Write-Host "1. Schedule Password Reset for Specific User"
    Write-Host "2. Schedule Password Reset for Users in Specific OU"
    Write-Host "3. Force Reset ALL Passwords on Next Login"
    Write-Host "Q. Quit"
    Write-Host "===================================" -ForegroundColor Cyan
}

function Reset-SingleUser {
    $user = Read-Host "Enter username to schedule password reset"
    try {
        Set-ADUser -Identity $user -PasswordNeverExpires $false
        Set-ADUser -Identity $user -ChangePasswordAtLogon $true
        Write-Host "`nSuccess: Scheduled password reset for user: $user" -ForegroundColor Green
    } catch {
        Write-Host "`nError: Failed to schedule reset for $user. $_" -ForegroundColor Red
    }
}

function Reset-OUUsers {
    # Get all OUs
    $OUs = Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName

    # Display OUs
    Write-Host "`nAvailable Organizational Units:"
    Write-Host "-----------------------------"
    for ($i = 0; $i -lt $OUs.Count; $i++) {
        Write-Host ("[{0}] {1}" -f ($i + 1), $OUs[$i].Name)
    }

    # Get selection
    do {
        $selection = Read-Host "`nEnter the number of the target OU"
        $selectionNum = [int]::TryParse($selection, [ref]$null)
    } while (-not $selectionNum -or [int]$selection -lt 1 -or [int]$selection -gt $OUs.Count)
    $selectedOU = $OUs[[int]$selection - 1]

    try {
        # Get all users in the OU
        $users = Get-ADUser -Filter * -SearchBase $selectedOU.DistinguishedName
        $userCount = ($users | Measure-Object).Count
        
        $confirm = Read-Host "This will schedule password reset for $userCount users in $($selectedOU.Name). Continue? (yes/no)"
        if ($confirm -eq "yes") {
            foreach ($user in $users) {
                try {
                    Set-ADUser -Identity $user -PasswordNeverExpires $false -ChangePasswordAtLogon $true
                    Write-Host "Scheduled reset for: $($user.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "Failed to schedule reset for: $($user.Name)" -ForegroundColor Red
                }
            }
            Write-Host "`nCompleted scheduling password resets for $($selectedOU.Name) OU" -ForegroundColor Cyan
        } else {
            Write-Host "`nOperation cancelled" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "`nError: Failed to process OU. $_" -ForegroundColor Red
    }
}

function Reset-AllUsers {
    # Define excluded OUs
    $excludedOUs = @(
        "OU=_ADMINS,DC=kendalltapani,DC=com",
        "OU=Domain Controllers,DC=kendalltapani,DC=com"
    )
    
    # Get all users except those in excluded OUs
    $allUsers = foreach ($excludedOU in $excludedOUs) {
        Get-ADUser -Filter * -Properties Name, DistinguishedName | 
        Where-Object { $_.DistinguishedName -notlike "*$excludedOU*" }
    }
    $allUsers = $allUsers | Sort-Object -Property Name -Unique
    $userCount = ($allUsers | Measure-Object).Count
    $excludedCount = (Get-ADUser -Filter * | Measure-Object).Count - $userCount

    Write-Host "`nWARNING: This will force password reset for $userCount users!" -ForegroundColor Red
    Write-Host "($excludedCount accounts in _ADMINS and Domain Controllers OUs will be excluded)" -ForegroundColor Yellow
    Write-Host "This action cannot be easily undone." -ForegroundColor Red
    
    # Three confirmations
    $confirm1 = Read-Host "`nType 'CONFIRM' to proceed with first confirmation"
    if ($confirm1 -eq "CONFIRM") {
        $confirm2 = Read-Host "Type 'I UNDERSTAND' for second confirmation"
        if ($confirm2 -eq "I UNDERSTAND") {
            $confirm3 = Read-Host "Type 'EXECUTE' for final confirmation"
            if ($confirm3 -eq "EXECUTE") {
                Write-Host "`nProceeding with domain-wide password reset (excluding protected OUs)..." -ForegroundColor Yellow
                $successCount = 0
                $failCount = 0
                
                foreach ($user in $allUsers) {
                    try {
                        # Additional safety check
                        if ($user.DistinguishedName -notlike "*OU=_ADMINS*" -and 
                            $user.DistinguishedName -notlike "*OU=Domain Controllers*") {
                            Set-ADUser -Identity $user -PasswordNeverExpires $false -ChangePasswordAtLogon $true
                            $successCount++
                            Write-Host "Scheduled reset for: $($user.Name)" -ForegroundColor Green
                        }
                    } catch {
                        $failCount++
                        Write-Host "Failed to schedule reset for: $($user.Name)" -ForegroundColor Red
                    }
                }
                
                Write-Host "`nOperation completed:" -ForegroundColor Cyan
                Write-Host "Successfully scheduled: $successCount users" -ForegroundColor Green
                Write-Host "Failed to schedule: $failCount users" -ForegroundColor Red
                Write-Host "Excluded: $excludedCount users (in protected OUs)" -ForegroundColor Yellow
            }
        }
    }
    
    if ($confirm1 -ne "CONFIRM" -or $confirm2 -ne "I UNDERSTAND" -or $confirm3 -ne "EXECUTE") {
        Write-Host "`nOperation cancelled" -ForegroundColor Yellow
    }
}

# Main loop
do {
    Show-Menu
    $selection = Read-Host "`nEnter your choice"
    
    switch ($selection) {
        '1' {
            Reset-SingleUser
            Read-Host "`nPress Enter to continue"
        }
        '2' {
            Reset-OUUsers
            Read-Host "`nPress Enter to continue"
        }
        '3' {
            Reset-AllUsers
            Read-Host "`nPress Enter to continue"
        }
        'Q' {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            return
        }
        default {
            Write-Host "`nInvalid selection. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true) 