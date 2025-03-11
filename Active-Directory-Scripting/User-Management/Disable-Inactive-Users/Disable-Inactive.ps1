# Disable Inactive Users Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to check for inactivity"
$inactiveDays = 30

$lastLogon = Get-ADUser -Identity $user -Properties LastLogonDate | Select-Object -ExpandProperty LastLogonDate
if ($lastLogon -lt (Get-Date).AddDays(-$inactiveDays)) {
    Disable-ADAccount -Identity $user
    Write-Host "Disabled inactive user: $user"
} else {
    Write-Host "User $user has been active within $inactiveDays days"
} 