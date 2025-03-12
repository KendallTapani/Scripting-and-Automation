# Move Users Between OUs Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to move"

# Get all OUs in the domain
$OUs = Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName

# Display OUs with numbers
Write-Host "`nAvailable Organizational Units:"
Write-Host "-----------------------------"
for ($i = 0; $i -lt $OUs.Count; $i++) {
    Write-Host ("[{0}] {1}" -f ($i + 1), $OUs[$i].Name)
}

# Get user selection
do {
    $selection = Read-Host "`nEnter the number of the target OU: "
    $selectionNum = [int]::TryParse($selection, [ref]$null)
} while (-not $selectionNum -or [int]$selection -lt 1 -or [int]$selection -gt $OUs.Count)

# Get selected OU
$selectedOU = $OUs[[int]$selection - 1]
$targetOU = $selectedOU.DistinguishedName

# Get current user location
$userObj = Get-ADUser -Identity $user
$userDN = $userObj.DistinguishedName

try {
    # Move the user
    Move-ADObject -Identity $userDN -TargetPath $targetOU
    Write-Host "`nSuccess: Moved user '$user' to '$($selectedOU.Name)' OU" -ForegroundColor Green
} catch {
    Write-Host "`nError: Failed to move user. $_" -ForegroundColor Red
    Write-Host "Please verify:"
    Write-Host "1. The user exists"
    Write-Host "2. You have permissions to move users"
    Write-Host "3. The target OU is valid"
} 