# Nested Group Auditing and Cleanup
# This script audits and helps clean up nested group memberships in Active Directory

# Import the Active Directory module
Import-Module ActiveDirectory

# Parameters
$reportPath = "C:\ADScripts\Reports\NestedGroups_$(Get-Date -Format 'yyyy-MM-dd').csv"
$maxNestedDepth = 5  # Maximum recommended nesting depth
$circularDetectionEnabled = $true
$logFile = "C:\ADScripts\Logs\NestedGroups_$(Get-Date -Format 'yyyy-MM-dd').log"

# Ensure directories exist
$reportDir = Split-Path $reportPath -Parent
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $reportDir)) { New-Item -Path $reportDir -ItemType Directory -Force }
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force }

# Start logging
Start-Transcript -Path $logFile -Append
Write-Host "$(Get-Date) - Starting nested group audit and cleanup"

# Function to get nested groups recursively
function Get-NestedGroups {
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName,
        
        [int]$CurrentDepth = 0,
        
        [array]$ParentChain = @()
    )
    
    # Get group details
    try {
        $group = Get-ADGroup -Identity $GroupName -Properties Members, Description
    }
    catch {
        Write-Warning "Could not find group: $GroupName. Error: $_"
        return $null
    }
    
    # Initialize results array
    $results = @()
    
    # Check for circular references
    if ($circularDetectionEnabled -and $ParentChain -contains $group.DistinguishedName) {
        $circularPath = ($ParentChain + $group.DistinguishedName) -join " -> "
        $results += [PSCustomObject]@{
            GroupName = $group.Name
            GroupDN = $group.DistinguishedName
            NestedGroupName = "CIRCULAR REFERENCE"
            NestedGroupDN = "CIRCULAR REFERENCE"
            NestingDepth = $CurrentDepth
            ParentChain = $circularPath
            IsCircular = $true
            ExceedsMaxDepth = ($CurrentDepth -gt $maxNestedDepth)
        }
        return $results
    }
    
    # Update parent chain
    $newParentChain = $ParentChain + $group.DistinguishedName
    
    # Process each member of the group
    foreach ($memberDN in $group.Members) {
        try {
            # Check if member is a group
            $memberObj = Get-ADObject -Identity $memberDN -Properties objectClass
            
            if ($memberObj.objectClass -eq "group") {
                $nestedGroup = Get-ADGroup -Identity $memberDN -Properties Description
                
                # Add this group to results
                $results += [PSCustomObject]@{
                    GroupName = $group.Name
                    GroupDN = $group.DistinguishedName
                    NestedGroupName = $nestedGroup.Name
                    NestedGroupDN = $nestedGroup.DistinguishedName
                    NestingDepth = $CurrentDepth + 1
                    ParentChain = ($newParentChain -join " -> ")
                    IsCircular = $false
                    ExceedsMaxDepth = (($CurrentDepth + 1) -gt $maxNestedDepth)
                }
                
                # Recursively process nested groups unless max depth exceeded
                if ($CurrentDepth + 1 -lt 20) {  # Hard limit to prevent infinite recursion
                    $results += Get-NestedGroups -GroupName $nestedGroup.DistinguishedName -CurrentDepth ($CurrentDepth + 1) -ParentChain $newParentChain
                }
            }
        }
        catch {
            Write-Warning "Error processing member $memberDN. Error: $_"
        }
    }
    
    return $results
}

# Get all security and distribution groups
$allGroups = Get-ADGroup -Filter * -Properties GroupCategory, GroupScope | Where-Object { $_.GroupCategory -eq "Security" -or $_.GroupCategory -eq "Distribution" }
Write-Host "Found $($allGroups.Count) groups to analyze"

# Process each group and collect nested group information
$nestedGroupsReport = @()
$groupCounter = 0
$totalGroups = $allGroups.Count

foreach ($group in $allGroups) {
    $groupCounter++
    Write-Progress -Activity "Analyzing nested groups" -Status "Processing $($group.Name)" -PercentComplete (($groupCounter / $totalGroups) * 100)
    
    $nestedGroups = Get-NestedGroups -GroupName $group.DistinguishedName
    
    if ($nestedGroups) {
        $nestedGroupsReport += $nestedGroups
    }
}

# Export results to CSV
$nestedGroupsReport | Export-Csv -Path $reportPath -NoTypeInformation
Write-Host "Nested groups report exported to $reportPath"

# Summary statistics
$circularReferences = $nestedGroupsReport | Where-Object { $_.IsCircular -eq $true }
$deepNesting = $nestedGroupsReport | Where-Object { $_.ExceedsMaxDepth -eq $true }

Write-Host "Audit Summary:"
Write-Host "- Total nested group relationships found: $($nestedGroupsReport.Count)"
Write-Host "- Circular references detected: $($circularReferences.Count)"
Write-Host "- Groups exceeding max nesting depth ($maxNestedDepth): $($deepNesting.Count)"

# Optional: Remove circular references automatically (commented out for safety)
<#
if ($circularReferences.Count -gt 0) {
    Write-Host "The following circular references were found:"
    $circularReferences | Format-Table -Property GroupName, NestedGroupName, ParentChain
    
    $proceed = Read-Host "Would you like to remove these circular references? (Y/N)"
    if ($proceed -eq "Y") {
        foreach ($ref in $circularReferences) {
            try {
                Remove-ADGroupMember -Identity $ref.GroupDN -Members $ref.NestedGroupDN -Confirm:$false
                Write-Host "Removed $($ref.NestedGroupName) from $($ref.GroupName)"
            }
            catch {
                Write-Warning "Failed to remove $($ref.NestedGroupName) from $($ref.GroupName). Error: $_"
            }
        }
    }
}
#>

# Optional: Suggest fixes for deep nesting
if ($deepNesting.Count -gt 0) {
    Write-Host "Groups with excessive nesting depth (>$maxNestedDepth) have been identified."
    Write-Host "Review the CSV report and consider flattening these group structures."
}

Stop-Transcript
