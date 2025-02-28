# Security Group Membership Reporting Script
# This script generates detailed reports of security group memberships and tracks changes over time

# Import required modules
Import-Module ActiveDirectory

# Configuration variables
$reportDir = "C:\Reports\SecurityGroups"
$previousReportDir = "$reportDir\Previous"
$currentReportDir = "$reportDir\Current"
$changeReportPath = "$reportDir\GroupMembershipChanges_$(Get-Date -Format 'yyyy-MM-dd').csv"
$htmlReportPath = "$reportDir\GroupMembershipReport_$(Get-Date -Format 'yyyy-MM-dd').html"
$logPath = "$reportDir\Logs\SecurityGroupReport_$(Get-Date -Format 'yyyy-MM-dd').log"

# Create necessary directories
foreach ($dir in @($reportDir, $previousReportDir, $currentReportDir, "$reportDir\Logs")) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Start logging
Start-Transcript -Path $logPath -Append

# Function to get nested group members (recursive)
function Get-NestedGroupMembers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeGroups
    )
    
    $group = Get-ADGroup -Identity $GroupName
    $members = Get-ADGroupMember -Identity $group -Recursive
    
    if (-not $IncludeGroups) {
        $members = $members | Where-Object { $_.objectClass -eq "user" }
    }
    
    $results = @()
    foreach ($member in $members) {
        try {
            if ($member.objectClass -eq "user") {
                $user = Get-ADUser -Identity $member.SamAccountName -Properties DisplayName, Title, Department, Enabled, WhenCreated, LastLogonDate
                $results += [PSCustomObject]@{
                    GroupName = $group.Name
                    MemberType = "User"
                    SamAccountName = $user.SamAccountName
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    Title = $user.Title
                    Department = $user.Department
                    Enabled = $user.Enabled
                    WhenCreated = $user.WhenCreated
                    LastLogonDate = $user.LastLogonDate
                }
            }
            elseif ($member.objectClass -eq "group" -and $IncludeGroups) {
                $nestedGroup = Get-ADGroup -Identity $member.SamAccountName
                $results += [PSCustomObject]@{
                    GroupName = $group.Name
                    MemberType = "Group"
                    SamAccountName = $nestedGroup.SamAccountName
                    DisplayName = $nestedGroup.Name
                    UserPrincipalName = $null
                    Title = $null
                    Department = $null
                    Enabled = $null
                    WhenCreated = $nestedGroup.WhenCreated
                    LastLogonDate = $null
                }
            }
        }
        catch {
            Write-Warning "Error processing member $($member.SamAccountName): $_"
        }
    }
    
    return $results
}

# Function to get direct group members (non-recursive)
function Get-DirectGroupMembers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeGroups
    )
    
    $group = Get-ADGroup -Identity $GroupName
    $members = Get-ADGroupMember -Identity $group
    
    if (-not $IncludeGroups) {
        $members = $members | Where-Object { $_.objectClass -eq "user" }
    }
    
    $results = @()
    foreach ($member in $members) {
        try {
            if ($member.objectClass -eq "user") {
                $user = Get-ADUser -Identity $member.SamAccountName -Properties DisplayName, Title, Department, Enabled, WhenCreated, LastLogonDate
                $results += [PSCustomObject]@{
                    GroupName = $group.Name
                    MemberType = "User"
                    SamAccountName = $user.SamAccountName
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    Title = $user.Title
                    Department = $user.Department
                    Enabled = $user.Enabled
                    WhenCreated = $user.WhenCreated
                    LastLogonDate = $user.LastLogonDate
                    DirectMember = $true
                }
            }
            elseif ($member.objectClass -eq "group" -and $IncludeGroups) {
                $nestedGroup = Get-ADGroup -Identity $member.SamAccountName
                $results += [PSCustomObject]@{
                    GroupName = $group.Name
                    MemberType = "Group"
                    SamAccountName = $nestedGroup.SamAccountName
                    DisplayName = $nestedGroup.Name
                    UserPrincipalName = $null
                    Title = $null
                    Department = $null
                    Enabled = $null
                    WhenCreated = $nestedGroup.WhenCreated
                    LastLogonDate = $null
                    DirectMember = $true
                }
            }
        }
        catch {
            Write-Warning "Error processing member $($member.SamAccountName): $_"
        }
    }
    
    return $results
}

# Function to get privileged/sensitive groups
function Get-SensitiveGroups {
    $sensitiveGroupNames = @(
        "Domain Admins",
        "Enterprise Admins",
        "Schema Admins",
        "Administrators",
        "Account Operators",
        "Backup Operators",
        "Server Operators",
        "Print Operators",
        "DNSAdmins",
        "Group Policy Creator Owners"
    )
    
    # Get custom sensitive groups (implement your organization's naming convention)
    # For example, any group with "Admin" in the name
    $customSensitiveGroups = Get-ADGroup -Filter "Name -like '*Admin*'" | Select-Object -ExpandProperty Name
    
    return $sensitiveGroupNames + $customSensitiveGroups | Sort-Object -Unique
}

# Generate security group report
function Generate-SecurityGroupReport {
    Write-Host "Generating security group membership reports..." -ForegroundColor Green
    
    # Get all privileged/sensitive groups
    $sensitiveGroups = Get-SensitiveGroups
    
    # Move current reports to previous directory
    if (Test-Path -Path "$currentReportDir\*.csv") {
        Get-ChildItem -Path "$currentReportDir\*.csv" | Move-Item -Destination $previousReportDir -Force
    }
    
    # Generate new reports
    foreach ($groupName in $sensitiveGroups) {
        try {
            Write-Host "Processing group: $groupName"
            
            # Get group members (both direct and nested)
            $directMembers = Get-DirectGroupMembers -GroupName $groupName -IncludeGroups
            $nestedMembers = Get-NestedGroupMembers -GroupName $groupName
            
            # Export to CSV
            $outputPath = "$currentReportDir\$($groupName -replace '[\\\/\:\*\?\"\<\>\|]', '_').csv"
            $allMembers = $directMembers + $nestedMembers | 
                Sort-Object -Property SamAccountName -Unique |
                Select-Object GroupName, MemberType, SamAccountName, DisplayName, UserPrincipalName, 
                    Title, Department, Enabled, WhenCreated, LastLogonDate, 
                    @{Name="DirectMember"; Expression={if ($_.DirectMember) { $true } else { $false }}}
            
            $allMembers | Export-Csv -Path $outputPath -NoTypeInformation
        }
        catch {
            Write-Warning "Error processing group $groupName : $_"
        }
    }
    
    # Check for changes
    Compare-GroupMembership
    
    # Generate HTML report
    Generate-HTMLReport
}

# Compare current and previous group membership reports
function Compare-GroupMembership {
    Write-Host "Comparing group membership with previous reports..." -ForegroundColor Green
    
    $changes = @()
    
    # Get current files
    $currentFiles = Get-ChildItem -Path "$currentReportDir\*.csv"
    
    foreach ($file in $currentFiles) {
        $groupName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $previousFile = "$previousReportDir\$($file.Name)"
        
        if (Test-Path -Path $previousFile) {
            $currentMembers = Import-Csv -Path $file.FullName
            $previousMembers = Import-Csv -Path $previousFile
            
            # Find added members
            $addedMembers = $currentMembers | Where-Object { 
                $currentMember = $_
                -not ($previousMembers | Where-Object { $_.SamAccountName -eq $currentMember.SamAccountName })
            }
            
            foreach ($member in $addedMembers) {
                $changes += [PSCustomObject]@{
                    Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                    ChangeType = "Added"
                    GroupName = $groupName
                    MemberType = $member.MemberType
                    SamAccountName = $member.SamAccountName
                    DisplayName = $member.DisplayName
                    DirectMember = $member.DirectMember
                }
            }
            
            # Find removed members
            $removedMembers = $previousMembers | Where-Object { 
                $previousMember = $_
                -not ($currentMembers | Where-Object { $_.SamAccountName -eq $previousMember.SamAccountName })
            }
            
            foreach ($member in $removedMembers) {
                $changes += [PSCustomObject]@{
                    Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                    ChangeType = "Removed"
                    GroupName = $groupName
                    MemberType = $member.MemberType
                    SamAccountName = $member.SamAccountName
                    DisplayName = $member.DisplayName
                    DirectMember = $member.DirectMember
                }
            }
        }
        else {
            # New group or first run
            $currentMembers = Import-Csv -Path $file.FullName
            
            foreach ($member in $currentMembers) {
                $changes += [PSCustomObject]@{
                    Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                    ChangeType = "Initial"
                    GroupName = $groupName
                    MemberType = $member.MemberType
                    SamAccountName = $member.SamAccountName
                    DisplayName = $member.DisplayName
                    DirectMember = $member.DirectMember
                }
            }
        }
    }
    
    # Export changes
    if ($changes.Count -gt 0) {
        $changes | Export-Csv -Path $changeReportPath -NoTypeInformation -Append
        Write-Host "Group membership changes saved to $changeReportPath" -ForegroundColor Green
    }
    else {
        Write-Host "No group membership changes detected." -ForegroundColor Yellow
    }
    
    return $changes
}

# Generate HTML report
function Generate-HTMLReport {
    Write-Host "Generating HTML report..." -ForegroundColor Green
    
    # Get all current reports
    $currentFiles = Get-ChildItem -Path "$currentReportDir\*.csv"
    
    # Create HTML header
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Security Group Membership Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        h2 { color: #3498db; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 30px; }
        th { background-color: #3498db; color: white; text-align: left; padding: 8px; }
        td { border: 1px solid #ddd; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        tr:hover { background-color: #ddd; }
        .disabled { color: #e74c3c; font-weight: bold; }
        .summary { background-color: #eaf2f8; padding: 10px; border-radius: 5px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>Security Group Membership Report</h1>
    <div class="summary">
        <p><strong>Report Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>Domain:</strong> $((Get-ADDomain).DNSRoot)</p>
        <p><strong>Total Groups Analyzed:</strong> $($currentFiles.Count)</p>
    </div>
"@
    
    # Process each group
    foreach ($file in $currentFiles) {
        $groupName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $members = Import-Csv -Path $file.FullName
        
        $html += "<h2>$groupName</h2>"
        
        # Group summary
        $totalMembers = $members.Count
        $directMembers = ($members | Where-Object { $_.DirectMember -eq $true }).Count
        $nestedMembers = $totalMembers - $directMembers
        $disabledMembers = ($members | Where-Object { $_.Enabled -eq $false }).Count
        
        $html += @"
    <div class="summary">
        <p><strong>Total Members:</strong> $totalMembers</p>
        <p><strong>Direct Members:</strong> $directMembers</p>
        <p><strong>Nested Members:</strong> $nestedMembers</p>
        <p><strong>Disabled Accounts:</strong> $disabledMembers</p>
    </div>
"@
        
        # Member table
        $html += @"
    <table>
        <tr>
            <th>Name</th>
            <th>Username</th>
            <th>Type</th>
            <th>Title</th>
            <th>Department</th>
            <th>Status</th>
            <th>Created</th>
            <th>Last Logon</th>
            <th>Membership</th>
        </tr>
"@
        
        foreach ($member in $members | Sort-Object -Property DisplayName) {
            $status = if ($member.Enabled -eq $false) { 'class="disabled">Disabled' } else { '">Enabled' }
            $membershipType = if ($member.DirectMember -eq $true) { "Direct" } else { "Nested" }
            
            $html += @"
        <tr>
            <td>$($member.DisplayName)</td>
            <td>$($member.SamAccountName)</td>
            <td>$($member.MemberType)</td>
            <td>$($member.Title)</td>
            <td>$($member.Department)</td>
            <td $status</td>
            <td>$($member.WhenCreated)</td>
            <td>$($member.LastLogonDate)</td>
            <td>$membershipType</td>
        </tr>
"@
        }
        
        $html += "    </table>"
    }
    
    # Recent changes section
    $html += "<h2>Recent Membership Changes</h2>"
    
    if (Test-Path -Path $changeReportPath) {
        $recentChanges = Import-Csv -Path $changeReportPath | 
            Sort-Object -Property Date -Descending | 
            Select-Object -First 50
        
        if ($recentChanges.Count -gt 0) {
            $html += @"
    <table>
        <tr>
            <th>Date</th>
            <th>Change Type</th>
            <th>Group</th>
            <th>Member</th>
            <th>Type</th>
            <th>Membership</th>
        </tr>
"@
            
            foreach ($change in $recentChanges) {
                $membershipType = if ($change.DirectMember -eq $true) { "Direct" } else { "Nested" }
                
                $html += @"
        <tr>
            <td>$($change.Date)</td>
            <td>$($change.ChangeType)</td>
            <td>$($change.GroupName)</td>
            <td>$($change.DisplayName) ($($change.SamAccountName))</td>
            <td>$($change.MemberType)</td>
            <td>$membershipType</td>
        </tr>
"@
            }
            
            $html += "    </table>"
        }
        else {
            $html += "<p>No recent changes found.</p>"
        }
    }
    else {
        $html += "<p>No change history available yet.</p>"
    }
    
    # Close HTML document
    $html += @"
</body>
</html>
"@
    
    # Save HTML report
    $html | Out-File -FilePath $htmlReportPath -Encoding UTF8
    Write-Host "HTML report saved to $htmlReportPath" -ForegroundColor Green
}

# Schedule this report to run daily
function Schedule-GroupMembershipReport {
    $taskName = "SecurityGroupMembershipReport"
    $taskDescription = "Generate daily security group membership reports"
    $scriptPath = $PSCommandPath
    
    # Create scheduled task action
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Create trigger (daily at 1 AM)
    $trigger = New-ScheduledTaskTrigger -Daily -At "1:00 AM"
    
    # Create principal (run with highest privileges)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Create task settings
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries

    # Register the task
    Register-ScheduledTask -TaskName $taskName -Description $taskDescription -Action $action -Principal $principal -Trigger $trigger -Settings $settings -Force
    
    Write-Host "Scheduled task '$taskName' created successfully." -ForegroundColor Green
}

# Main execution block
Generate-SecurityGroupReport

# Optional: Schedule the report to run daily
# Schedule-GroupMembershipReport

# Stop logging
Stop-Transcript

# Example usage:
# .\SecurityGroupReport.ps1
