# User Onboarding Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to onboard"

$password = ConvertTo-SecureString "Welcome123!" -AsPlainText -Force
New-ADUser -Name $user `
           -SamAccountName $user.ToLower() `
           -UserPrincipalName "$user@$domain" `
           -Enabled $true `
           -PasswordNeverExpires $false `
           -ChangePasswordAtLogon $true `
           -AccountPassword $password
Write-Host "Created user: $user" 