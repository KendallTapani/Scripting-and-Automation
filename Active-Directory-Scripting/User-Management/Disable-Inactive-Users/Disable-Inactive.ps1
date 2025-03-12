# Disable Inactive Users Script for kendalltapani.com
$domain = "kendalltapani.com"
$inactiveDays = 30

Write-Host "Searching for inactive users... Please wait" -NoNewline
$progressChar = "."
$progressTimer = [System.Diagnostics.Stopwatch]::StartNew()

# Get all enabled users and their last logon dates
$users = Get-ADUser -Filter {Enabled -eq $true} -Properties LastLogonDate | 
    Select-Object Name, LastLogonDate, @{
        Name='DaysSinceLogon';
        Expression={(New-TimeSpan -Start $_.LastLogonDate -End (Get-Date)).Days}
    }

$inactiveUsers = @()
$counter = 1

foreach ($user in $users) {
    # Show loading animation
    if ($progressTimer.ElapsedMilliseconds -gt 500) {
        Write-Host $progressChar -NoNewline
        $progressTimer.Restart()
    }
    
    if ($user.DaysSinceLogon -gt $inactiveDays) {
        $inactiveUsers += @{
            Number = $counter
            Name = $user.Name
            DaysSinceLogon = $user.DaysSinceLogon
        }
        $counter++
    }
}

# Clear the loading line and show results
Write-Host "`n`nSearch Complete!"
Write-Host "=====================`n"

if ($inactiveUsers.Count -eq 0) {
    Write-Host "No inactive users found!"
    exit
}

Write-Host "Found $($inactiveUsers.Count) inactive users:`n"
foreach ($user in $inactiveUsers) {
    Write-Host "[$($user.Number)] $($user.Name)"
    Write-Host "    Inactive for: $($user.DaysSinceLogon) days`n"
}

Write-Host "Enter the numbers of users to disable (comma-separated) or 'all' for all inactive users:"
$selection = Read-Host

$selectedUsers = @()
if ($selection -eq "all") {
    $selectedUsers = $inactiveUsers
} else {
    $numbers = $selection -split ',' | ForEach-Object { $_.Trim() }
    $selectedUsers = $inactiveUsers | Where-Object { $numbers -contains $_.Number }
}

Write-Host "`nThe following users will be disabled:"
foreach ($user in $selectedUsers) {
    Write-Host "- $($user.Name) (Inactive for $($user.DaysSinceLogon) days)"
}

$confirm = Read-Host "`nType 'yes' to confirm"
if ($confirm -eq "yes") {
    foreach ($user in $selectedUsers) {
        try {
            Disable-ADAccount -Identity $user.Name
            Write-Host "Disabled user: $($user.Name)"
        } catch {
            Write-Host "Error disabling user $($user.Name): $_"
        }
    }
} else {
    Write-Host "Operation cancelled"
}