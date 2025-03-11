# Schedule Password Reset Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to schedule password reset"
$maxPasswordAge = 90

Set-ADUser -Identity $user -PasswordNeverExpires $false
$pwdLastSet = Get-ADUser -Identity $user -Properties PasswordLastSet | Select-Object -ExpandProperty PasswordLastSet
if ($pwdLastSet -lt (Get-Date).AddDays(-$maxPasswordAge)) {
    Set-ADUser -Identity $user -ChangePasswordAtLogon $true
    Write-Host "Scheduled password reset for user: $user"
} else {
    Write-Host "Password for $user is still within $maxPasswordAge days age limit"
} 