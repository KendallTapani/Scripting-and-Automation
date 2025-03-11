# User Creation Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to create"
$password = ConvertTo-SecureString "Welcome123!" -AsPlainText -Force

New-ADUser -Name $user `
           -SamAccountName $user.ToLower() `
           -UserPrincipalName "$user@$domain" `
           -Enabled $true `
           -AccountPassword $password `
           -Path "CN=Users,DC=kendalltapani,DC=com"
Write-Host "Created user: $user" 