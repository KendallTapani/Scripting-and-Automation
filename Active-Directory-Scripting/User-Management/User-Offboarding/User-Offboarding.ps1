# User Offboarding Script for kendalltapani.com
$domain = "kendalltapani.com"

function Show-Menu {
    Clear-Host
    Write-Host "=== User Offboarding Tool ===" -ForegroundColor Cyan
    Write-Host "1. Offboard Single User"
    Write-Host "2. View Users Pending Deletion"
    Write-Host "3. Process Deletions (30+ days disabled)"
    Write-Host "Q. Quit"
    Write-Host "===========================" -ForegroundColor Cyan
}

function Disable-UserAccount {
    param (
        [string]$username
    )
    
    try {
        # Get user details
        $user = Get-ADUser -Identity $username -Properties LastLogonDate
        
        # Confirm with admin
        Write-Host "`nUser Details:" -ForegroundColor Yellow
        Write-Host "Username: $($user.SamAccountName)"
        Write-Host "Name: $($user.Name)"
        Write-Host "Last Logon: $($user.LastLogonDate)"
        
        $confirm = Read-Host "`nAre you sure you want to offboard this user? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "Operation cancelled" -ForegroundColor Yellow
            return
        }

        # 1. Disable account
        Disable-ADAccount -Identity $username
        Write-Host "Account disabled successfully" -ForegroundColor Green

        # 2. Move to Disabled Users OU
        $disabledOU = "OU=Disabled Users,DC=kendalltapani,DC=com"
        
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $disabledOU
        Write-Host "Moved to Disabled Users OU" -ForegroundColor Green

        # 3. Add deletion date to description (30 days from now)
        $deletionDate = (Get-Date).AddDays(30).ToString("yyyy-MM-dd")
        Set-ADUser -Identity $username -Description "Scheduled for deletion on: $deletionDate"
        Write-Host "Set deletion date to $deletionDate" -ForegroundColor Green

        Write-Host "`nOffboarding completed successfully" -ForegroundColor Green

    } catch {
        Write-Host "Error processing user: $_" -ForegroundColor Red
    }
}

function Show-PendingDeletions {
    try {
        $disabledOU = "OU=Disabled Users,DC=kendalltapani,DC=com"
        $users = Get-ADUser -Filter * -SearchBase $disabledOU -Properties Description, LastLogonDate |
                Where-Object { $_.Description -like "Scheduled for deletion*" }

        if ($users) {
            Write-Host "`nUsers Pending Deletion:" -ForegroundColor Yellow
            Write-Host "----------------------"
            foreach ($user in $users) {
                $deletionDate = ($user.Description -split ": ")[1]
                $daysLeft = (([datetime]$deletionDate) - (Get-Date)).Days
                
                Write-Host "Username: $($user.SamAccountName)"
                Write-Host "Deletion Date: $deletionDate"
                Write-Host "Days Remaining: $daysLeft"
                Write-Host "----------------------"
            }
        } else {
            Write-Host "`nNo users pending deletion" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error retrieving pending deletions: $_" -ForegroundColor Red
    }
}

function Process-Deletions {
    try {
        $disabledOU = "OU=Disabled Users,DC=kendalltapani,DC=com"
        $users = Get-ADUser -Filter * -SearchBase $disabledOU -Properties Description |
                Where-Object { $_.Description -like "Scheduled for deletion*" }

        $deletionCount = 0
        foreach ($user in $users) {
            $deletionDate = ([datetime]($user.Description -split ": ")[1])
            if ($deletionDate -lt (Get-Date)) {
                $confirm = Read-Host "Delete user $($user.SamAccountName)? (yes/no)"
                if ($confirm -eq "yes") {
                    Remove-ADUser -Identity $user -Confirm:$false
                    Write-Host "Deleted user: $($user.SamAccountName)" -ForegroundColor Green
                    $deletionCount++
                }
            }
        }

        if ($deletionCount -eq 0) {
            Write-Host "`nNo users ready for deletion" -ForegroundColor Yellow
        } else {
            Write-Host "`nDeleted $deletionCount users" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error processing deletions: $_" -ForegroundColor Red
    }
}

# Main loop
do {
    Show-Menu
    $selection = Read-Host "`nEnter your choice"
    
    switch ($selection) {
        '1' {
            $username = Read-Host "Enter username to offboard"
            Disable-UserAccount -username $username
            Read-Host "`nPress Enter to continue"
        }
        '2' {
            Show-PendingDeletions
            Read-Host "`nPress Enter to continue"
        }
        '3' {
            Process-Deletions
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