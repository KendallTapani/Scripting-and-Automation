# User Onboarding Script for kendalltapani.com
$domain = "kendalltapani.com"
$defaultPassword = "Password1"

function Show-Menu {
    Clear-Host
    Write-Host "=== User Onboarding Tool ===" -ForegroundColor Cyan
    Write-Host "1. Create New User Account"
    Write-Host "2. View Recent Onboarding History"
    Write-Host "Q. Quit"
    Write-Host "===========================" -ForegroundColor Cyan
}

function New-StandardUser {
    try {
        # Get user details
        $firstName = Read-Host "Enter user's first name"
        $lastName = Read-Host "Enter user's last name"
        
        # Generate username (first letter of first name + last name)
        $username = ($firstName.Substring(0,1) + $lastName).ToLower()
        
        # Check if username already exists
        if (Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue) {
            Write-Host "`nWarning: Username $username already exists!" -ForegroundColor Yellow
            $counter = 1
            while (Get-ADUser -Filter "SamAccountName -eq '$username$counter'" -ErrorAction SilentlyContinue) {
                $counter++
            }
            $username = "$username$counter"
            Write-Host "Using alternative username: $username" -ForegroundColor Yellow
        }

        # Get all OUs and display them
        $OUs = Get-ADOrganizationalUnit -Filter * | 
               Where-Object { $_.DistinguishedName -notlike "*Domain Controllers*" } |
               Select-Object Name, DistinguishedName |
               Sort-Object Name

        Write-Host "`nAvailable Organizational Units:"
        Write-Host "-----------------------------"
        for ($i = 0; $i -lt $OUs.Count; $i++) {
            Write-Host ("[{0}] {1}" -f ($i + 1), $OUs[$i].Name)
        }
        
        do {
            $selection = Read-Host "`nSelect department OU (1-$($OUs.Count))"
            $selectionNum = [int]::TryParse($selection, [ref]$null)
        } while (-not $selectionNum -or [int]$selection -lt 1 -or [int]$selection -gt $OUs.Count)

        # Get selected OU
        $selectedOU = $OUs[[int]$selection - 1]
        $targetOU = $selectedOU.DistinguishedName

        # Set initial password
        $securePassword = ConvertTo-SecureString -String $defaultPassword -AsPlainText -Force

        # Create new user
        New-ADUser `
            -SamAccountName $username `
            -UserPrincipalName "$username@$domain" `
            -Name "$firstName $lastName" `
            -GivenName $firstName `
            -Surname $lastName `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -Path $targetOU `
            -AccountPassword $securePassword

        # Add to basic groups based on department
        $basicGroups = @("Users")
        
        # Try to add to department group if it exists
        $deptGroup = "$($selectedOU.Name) Users"
        if (Get-ADGroup -Filter "Name -eq '$deptGroup'" -ErrorAction SilentlyContinue) {
            $basicGroups += $deptGroup
        }

        foreach ($group in $basicGroups) {
            try {
                Add-ADGroupMember -Identity $group -Members $username
                Write-Host "Added to group: $group" -ForegroundColor Green
            } catch {
                Write-Host "Warning: Could not add to group $group" -ForegroundColor Yellow
            }
        }

        # Display success message and account details
        Write-Host "`nUser Account Created Successfully!" -ForegroundColor Green
        Write-Host "--------------------------------"
        Write-Host "Username: $username"
        Write-Host "Initial Password: $defaultPassword"
        Write-Host "Full Name: $firstName $lastName"
        Write-Host "OU: $($selectedOU.Name)"
        Write-Host "Groups: $($basicGroups -join ', ')"
        Write-Host "`nPlease provide these credentials to the user securely."
        Write-Host "User will be prompted to change password at first login."

    } catch {
        Write-Host "`nError creating user: $_" -ForegroundColor Red
    }
}

function Show-OnboardingHistory {
    try {
        $recentUsers = Get-ADUser -Filter * -Properties Created |
                      Where-Object { $_.Created -gt (Get-Date).AddDays(-30) } |
                      Sort-Object Created -Descending

        if ($recentUsers) {
            Write-Host "`nRecently Created Users (Last 30 Days):" -ForegroundColor Yellow
            Write-Host "------------------------------------"
            foreach ($user in $recentUsers) {
                Write-Host "Username: $($user.SamAccountName)"
                Write-Host "Name: $($user.Name)"
                Write-Host "Created: $($user.Created)"
                Write-Host "------------------------------------"
            }
        } else {
            Write-Host "`nNo users created in the last 30 days" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error retrieving history: $_" -ForegroundColor Red
    }
}

# Main loop
do {
    Show-Menu
    $selection = Read-Host "`nEnter your choice"
    
    switch ($selection) {
        '1' {
            New-StandardUser
            Read-Host "`nPress Enter to continue"
        }
        '2' {
            Show-OnboardingHistory
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