# Lock/Unlock Accounts Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to manage"
$action = Read-Host "Enter action (lock/unlock)"

if ($action -eq "lock") {
    Disable-ADAccount -Identity $user
    Write-Host "Locked account: $user"
} elseif ($action -eq "unlock") {
    Enable-ADAccount -Identity $user
    Write-Host "Unlocked account: $user"
} else {
    Write-Host "Invalid action. Please use 'lock' or 'unlock'"
} 