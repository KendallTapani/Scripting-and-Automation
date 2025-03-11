# Move Users Between OUs Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to move"
$targetOU = "OU=IT Department,DC=kendalltapani,DC=com"

$userDN = "CN=$user,CN=Users,DC=kendalltapani,DC=com"
Move-ADObject -Identity $userDN -TargetPath $targetOU
Write-Host "Moved user $user to IT Department OU" 