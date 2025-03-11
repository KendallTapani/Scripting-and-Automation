# Password Reset Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to reset password"
$newPassword = ConvertTo-SecureString "NewPass123!" -AsPlainText -Force

Set-ADAccountPassword -Identity $user -NewPassword $newPassword -Reset
Set-ADUser -Identity $user -ChangePasswordAtLogon $true
Write-Host "Reset password for user: $user" 