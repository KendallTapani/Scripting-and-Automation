# Dynamic Group Membership Automation
# This script manages group membership based on user attributes in Active Directory

# Import the Active Directory module
Import-Module ActiveDirectory

# Parameters - customize these for your environment
$targetGroup = "Marketing-Department"
$attributeName = "Department"
$attributeValue = "Marketing"
$logFile = "C:\ADScripts\Logs\DynamicGroups_$(Get-Date -Format 'yyyy-MM-dd').log"

# Ensure log directory exists
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force
}

# Start logging
Start-Transcript -Path $logFile -Append
Write-Host "$(Get-Date) - Starting dynamic group membership update for $targetGroup based on $attributeName = $attributeValue"

# Get current group members
$currentMembers = Get-ADGroupMember -Identity $targetGroup | Select-Object -ExpandProperty DistinguishedName

# Get users with the specified attribute
$targetUsers = Get-ADUser -Filter "$attributeName -eq '$attributeValue'" -Properties $attributeName | 
    Select-Object -ExpandProperty DistinguishedName

# Track changes
$addedUsers = 0
$removedUsers = 0

# Add users who should be in the group but aren't
foreach ($user in $targetUsers) {
    if ($user -notin $currentMembers) {
        try {
            Add-ADGroupMember -Identity $targetGroup -Members $user -ErrorAction Stop
            Write-Host "Added user $user to group $targetGroup"
            $addedUsers++
        }
        catch {
            Write-Warning "Failed to add user $user to group $targetGroup. Error: $_"
        }
    }
}

# Remove users who are in the group but shouldn't be
foreach ($member in $currentMembers) {
    # Skip non-user objects (like nested groups)
    try {
        $userObj = Get-ADUser -Identity $member -Properties $attributeName -ErrorAction SilentlyContinue
        if ($userObj -and ($userObj.DistinguishedName -notin $targetUsers)) {
            Remove-ADGroupMember -Identity $targetGroup -Members $member -Confirm:$false -ErrorAction Stop
            Write-Host "Removed user $member from group $targetGroup"
            $removedUsers++
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # This is likely a group or other non-user object, skip
        Write-Verbose "Skipping non-user object: $member"
    }
    catch {
        Write-Warning "Error processing member $member. Error: $_"
    }
}

# Summary
Write-Host "Dynamic group update complete. Added: $addedUsers, Removed: $removedUsers"
Write-Host "Total members now: $((Get-ADGroupMember -Identity $targetGroup).Count)"

# For bulk management - multiple attributes or groups
function Update-DynamicGroupMembership {
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName,
        
        [Parameter(Mandatory=$true)]
        [string]$AttributeName,
        
        [Parameter(Mandatory=$true)]
        [string]$AttributeValue
    )
    
    # Implementation similar to the main script
    Write-Host "Updating group $GroupName based on $AttributeName = $AttributeValue"
    # ...implementation details...
}

# Example of processing multiple groups from a CSV
<#
$groupConfigs = Import-Csv -Path "C:\ADScripts\DynamicGroups.csv"
foreach ($config in $groupConfigs) {
    Update-DynamicGroupMembership -GroupName $config.GroupName -AttributeName $config.Attribute -AttributeValue $config.Value
}
#>

Stop-Transcript