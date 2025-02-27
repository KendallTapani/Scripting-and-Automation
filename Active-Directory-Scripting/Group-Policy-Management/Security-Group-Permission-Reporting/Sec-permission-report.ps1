# Security Group Permissions Reporting
# This script generates comprehensive reports on security group permissions

# Import required modules
Import-Module ActiveDirectory

# Parameters
$reportFolder = "C:\ADScripts\Reports\SecurityGroups"
$logFile = "C:\ADScripts\Logs\SecurityGroupReporting_$(Get-Date -Format 'yyyy-MM-dd').log"
$fileServerPaths = @("\\fileserver\share1", "\\fileserver\share2")  # Add your file shares

# Ensure directories exist
if (-not (Test-Path $reportFolder)) { New-Item -Path $reportFolder -ItemType Directory -Force }
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force }

# Start logging
Start-Transcript -Path $logFile -Append
Write-Host "$(Get-Date) - Starting security group permissions reporting"

# Function to get all security groups
function Get-AllSecurityGroups {
    try {
        $securityGroups = Get-ADGroup -Filter 'GroupCategory -eq "Security"' -Properties Description, WhenCreated, WhenChanged, ManagedBy, Member
        Write-Host "Found $($securityGroups.Count) security groups"
        return $securityGroups
    }
    catch {
        Write-Error "Failed to retrieve security groups: $_"
        return $null
    }
}

# Function to get group membership details
function Get-GroupMembershipDetails {
    param (
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADGroup]$Group
    )
    
    $members = @()
    
    try {
        # Get direct members
        $directMembers = Get-ADGroupMember -Identity $Group -ErrorAction Stop
        
        foreach ($member in $directMembers) {
            $memberObj = [PSCustomObject]@{
                GroupName = $Group.Name
                MemberName = $member.Name
                MemberType = $member.objectClass
                SamAccountName = $member.SamAccountName
                IsDirect = $true
                MemberDN = $member.DistinguishedName
            }
            
            $members += $memberObj
        }
    }
    catch {
        Write-Warning "Error getting members for group $($Group.Name): $_"
    }
    
    return $members
}

# Function to get file system permissions
function Get-FileSystemPermissions {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADGroup]$Group
    )
    
    if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
        Write-Warning "Path not found or not accessible: $Path"
        return $null
    }
    
    try {
        # Get ACL
        $acl = Get-Acl -Path $Path
        
        # Filter for the specific group
        $groupPermissions = $acl.Access | Where-Object { 
            $_.IdentityReference.Value -like "*\$($Group.Name)" -or 
            $_.IdentityReference.Value -eq $Group.SID.Value
        }
        
        if (-not $groupPermissions) {
            return $null
        }
        
        $permissions = @()
        
        foreach ($perm in $groupPermissions) {
            $permissions += [PSCustomObject]@{
                GroupName = $Group.Name
                Path = $Path
                AccessType = $perm.AccessControlType
                Rights = $perm.FileSystemRights
                Inheritance = $perm.InheritanceFlags
                Propagation = $perm.PropagationFlags
                IdentityReference = $perm.IdentityReference.Value
            }
        }
        
        return $permissions
    }
    catch {
        Write-Warning "Error getting permissions for path $Path and group $($Group.Name): $_"
        return $null
    }
}

# Function to scan directories recursively for group permissions
function Scan-DirectoryPermissions {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADGroup]$Group,
        
        [int]$MaxDepth = 3,
        
        [int]$CurrentDepth = 0
    )
    
    if ($CurrentDepth -gt $MaxDepth) {
        return @()
    }
    
    $permissions = @()
    
    # Get permissions on the current directory
    $dirPerms = Get-FileSystemPermissions -Path $BasePath -Group $Group
    if ($dirPerms) {
        $permissions += $dirPerms
    }
    
    # Only recurse if we're not at max depth
    if ($CurrentDepth -lt $MaxDepth) {
        try {
            $subDirs = Get-ChildItem -Path $BasePath -Directory -ErrorAction SilentlyContinue
            
            foreach ($dir in $subDirs) {
                $subPerms = Scan-DirectoryPermissions -BasePath $dir.FullName -Group $Group -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
                $permissions += $subPerms
            }
        }
        catch {
            Write-Warning "Error scanning subdirectories in $($BasePath): $_"
        }
    }
    
    return $permissions
}

# Function to get group GPO permissions
function Get-GroupGPOPermissions {
    param (
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADGroup]$Group
    )
    
    try {
        # Requires the GroupPolicy module
        if (-not (Get-Module -Name GroupPolicy -ListAvailable)) {
            Write-Warning "GroupPolicy module not available. Skipping GPO permission scan."
            return $null
        }
        
        Import-Module GroupPolicy
        
        $gpos = Get-GPO -All
        $permissions = @()
        
        foreach ($gpo in $gpos) {
            $gpoSecurity = Get-GPPermission -Guid $gpo.Id -All
            
            $groupPerms = $gpoSecurity | Where-Object { 
                $_.Trustee.Name -eq $Group.Name -or 
                $_.Trustee.SID.Value -eq $Group.SID.Value
            }
            
            if ($groupPerms) {
                foreach ($perm in $groupPerms) {
                    $permissions += [PSCustomObject]@{
                        GroupName = $Group.Name
                        GPOName = $gpo.DisplayName
                        GPOID = $gpo.Id
                        Permission = $perm.Permission
                        Inherited = $perm.Inherited
                    }
                }
            }
        }
        
        return $permissions
    }
    catch {
        Write-Warning "Error getting GPO permissions for group $($Group.Name): $_"
        return $null
    }
}

# Main reporting function
function Generate-SecurityGroupReport {
    # Get all security groups
    $securityGroups = Get-AllSecurityGroups
    
    if (-not $securityGroups) {
        Write-Error "No security groups found or unable to retrieve them."
        return
    }
    
    # Group overview report
    $groupOverviewReport = @()
    $groupMembershipReport = @()
    $filePermissionsReport = @()
    $gpoPermissionsReport = @()
    
    $groupCounter = 0
    $totalGroups = $securityGroups.Count
    
    foreach ($group in $securityGroups) {
        $groupCounter++
        Write-Progress -Activity "Analyzing Security Groups" -Status "Processing $($group.Name)" -PercentComplete (($groupCounter / $totalGroups) * 100)
        
        # Basic group info
        $memberCount = if ($group.Member) { $group.Member.Count } else { 0 }
        $managerName = ""
        
        if ($group.ManagedBy) {
            try {
                $manager = Get-ADObject -Identity $group.ManagedBy -Properties DisplayName -ErrorAction SilentlyContinue
                $managerName = $manager.DisplayName
            }
            catch {
                $managerName = "Unknown"
            }
        }
        
        $groupOverviewReport += [PSCustomObject]@{
            Name = $group.Name
            Description = $group.Description
            Manager = $managerName
            MemberCount = $memberCount
            Created = $group.WhenCreated
            LastChanged = $group.WhenChanged
            DistinguishedName = $group.DistinguishedName
            SID = $group.SID.Value
            Scope = $group.GroupScope
        }
        
        # Get group membership details
        $members = Get-GroupMembershipDetails -Group $group
        $groupMembershipReport += $members
        
        # Get file system permissions for this group
        foreach ($path in $fileServerPaths) {
            if (Test-Path $path -ErrorAction SilentlyContinue) {
                Write-Host "Scanning file permissions for $($group.Name) on $path..."
                $permissions = Scan-DirectoryPermissions -BasePath $path -Group $group
                $filePermissionsReport += $permissions
            }
        }
        
        # Get GPO permissions for this group
        $gpoPermissions = Get-GroupGPOPermissions -Group $group
        $gpoPermissionsReport += $gpoPermissions
    }
    
    # Export reports
    $timestamp = Get-Date -Format 'yyyy-MM-dd'
    
    $groupOverviewReport | Export-Csv -Path "$reportFolder\GroupOverview_$timestamp.csv" -NoTypeInformation
    Write-Host "Group overview report exported to $reportFolder\GroupOverview_$timestamp.csv"
    
    $groupMembershipReport | Export-Csv -Path "$reportFolder\GroupMembership_$timestamp.csv" -NoTypeInformation
    Write-Host "Group membership report exported to $reportFolder\GroupMembership_$timestamp.csv"
    
    if ($filePermissionsReport) {
        $filePermissionsReport | Export-Csv -Path "$reportFolder\FilePermissions_$timestamp.csv" -NoTypeInformation
        Write-Host "File permissions report exported to $reportFolder\FilePermissions_$timestamp.csv"
    }
    
    if ($gpoPermissionsReport) {
        $gpoPermissionsReport | Export-Csv -Path "$reportFolder\GPOPermissions_$timestamp.csv" -NoTypeInformation
        Write-Host "GPO permissions report exported to $reportFolder\GPOPermissions_$timestamp.csv"
    }
    
    # Generate HTML summary report
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Security Group Permissions Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        h1, h2 { color: #333366; }
        .summary { margin-bottom: 30px; }
    </style>
</head>
<body>
    <h1>Security Group Permissions Report</h1>
    <p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Security Groups: $($groupOverviewReport.Count)</p>
        <p>Total Unique File Permissions: $($filePermissionsReport.Count)</p>
        <p>Total GPO Permissions: $($gpoPermissionsReport.Count)</p>
    </div>
    
    <h2>Groups with Most Members</h2>
    <table>
        <tr>
            <th>Group Name</th>
            <th>Member Count</th>
            <th>Description</th>
        </tr>
"@

    $topGroups = $groupOverviewReport | Sort-Object MemberCount -Descending | Select-Object -First 10
    
    foreach ($group in $topGroups) {
        $htmlReport += @"
        <tr>
            <td>$($group.Name)</td>
            <td>$($group.MemberCount)</td>
            <td>$($group.Description)</td>
        </tr>
"@
    }
    
    $htmlReport += @"
    </table>
    
    <h2>Groups with Most File Permissions</h2>
    <table>
        <tr>
            <th>Group Name</th>
            <th>Permission Count</th>
        </tr>
"@

    $topFilePermGroups = $filePermissionsReport | Group-Object GroupName | 
                        Select-Object Name, Count | Sort-Object Count -Descending | 
                        Select-Object -First 10
    
    foreach ($group in $topFilePermGroups) {
        $htmlReport += @"
        <tr>
            <td>$($group.Name)</td>
            <td>$($group.Count)</td>
        </tr>
"@
    }
    
    $htmlReport += @"
    </table>
    
    <h2>Groups with GPO Permissions</h2>
    <table>
        <tr>
            <th>Group Name</th>
            <th>GPO Count</th>
        </tr>
"@

    $gpoGroups = $gpoPermissionsReport | Group-Object GroupName | 
                Select-Object Name, Count | Sort-Object Count -Descending
    
    foreach ($group in $gpoGroups) {
        $htmlReport += @"
        <tr>
            <td>$($group.Name)</td>
            <td>$($group.Count)</td>
        </tr>
"@
    }
    
    $htmlReport += @"
    </table>
    
    <p>For detailed information, please refer to the CSV reports in the report folder.</p>
</body>
</html>
"@

    $htmlReport | Out-File -FilePath "$reportFolder\SecurityGroupReport_$timestamp.html" -Force
    Write-Host "HTML summary report exported to $reportFolder\SecurityGroupReport_$timestamp.html"
}