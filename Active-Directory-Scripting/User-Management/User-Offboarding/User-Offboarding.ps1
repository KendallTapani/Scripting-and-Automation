# User Offboarding Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to offboard"

Disable-ADAccount -Identity $user
Move-ADObject -Identity "CN=$user,CN=Users,DC=kendalltapani,DC=com" -TargetPath "OU=Disabled Users,DC=kendalltapani,DC=com"
Write-Host "Disabled and moved user: $user" 