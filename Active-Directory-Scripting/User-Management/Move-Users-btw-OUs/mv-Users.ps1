# Import the Active Directory module
Import-Module ActiveDirectory

# Set up logging
$logPath = "C:\Logs\UserMove_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logPath

# Define the base DN for your domain
$domainDN = "DC=contoso,DC=com"

# Define mapping of attribute values to target OUs
$ouMapping = @{
    # Department attribute mappings
    Department = @{
        "Marketing" = "OU=Marketing,OU=Departments,$domainDN"
        "Finance" = "OU=Finance,OU=Departments,$domainDN"
        "IT" = "OU=IT,OU=Departments,$domainDN"
    }
    # Office attribute mappings
    Office = @{
        "New York" = "OU=NewYork,OU=Offices,$domainDN"
        "London" = "OU=London,OU=Offices,$domainDN"
        "Tokyo" = "OU=Tokyo,OU=Offices,$domainDN"
    }
    # You can add more attributes here
}

# Process each attribute type
foreach ($attributeName in $ouMapping.Keys) {
    Write-Host "Processing users based on $attributeName attribute..." -ForegroundColor Cyan
    
    # Process each value for this attribute
    foreach ($attributeValue in $ouMapping[$attributeName].Keys) {
        $targetOU = $ouMapping[$attributeName][$attributeValue]
        
        # Find users with this attribute value anywhere in the domain
        Write-Host "Finding users with $attributeName = '$attributeValue'..." -ForegroundColor Yellow
        $usersToMove = Get-ADUser -Filter "$attributeName -eq '$attributeValue'" -SearchBase $domainDN
        
        if ($usersToMove.Count -eq 0) {
            Write-Host "No users found with $attributeName = '$attributeValue'." -ForegroundColor Gray
            continue
        }
        
        Write-Host "Found $($usersToMove.Count) users with $attributeName = '$attributeValue'." -ForegroundColor Green
        
        # Move each user to the appropriate OU
        foreach ($user in $usersToMove) {
            # Skip if the user is already in the correct OU
            $userOU = ($user.DistinguishedName -split ',', 2)[1]
            $targetOUParent = ($targetOU -split ',', 2)[1]
            
            if ($userOU -eq $targetOUParent) {
                Write-Host "User $($user.Name) is already in the correct OU structure." -ForegroundColor Gray
                continue
            }
            
            # Move the user
            try {
                Move-ADObject -Identity $user.DistinguishedName -TargetPath $targetOU
                Write-Host "Successfully moved user $($user.Name) to $targetOU" -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to move user $($user.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "Operation completed. See log file for details: $logPath" -ForegroundColor Cyan
Stop-Transcript