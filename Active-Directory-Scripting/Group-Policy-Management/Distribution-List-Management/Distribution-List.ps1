# Distribution List Management
# This script helps manage Active Directory distribution lists

# Import required modules
Import-Module ActiveDirectory
# For Exchange functionality (uncomment if Exchange management shell is installed)
# Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue

# Parameters
$reportPath = "C:\ADScripts\Reports\DistributionLists_$(Get-Date -Format 'yyyy-MM-dd').csv"
$dlListFile = "C:\ADScripts\DistributionLists.csv"  # CSV with group names and owners
$logFile = "C:\ADScripts\Logs\DistributionLists_$(Get-Date -Format 'yyyy-MM-dd').log"

# Ensure directories exist
$reportDir = Split-Path $reportPath -Parent
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $reportDir)) { New-Item -Path $reportDir -ItemType Directory -Force }
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force }

# Start logging
Start-Transcript -Path $logFile -Append
Write-Host "$(Get-Date) - Starting distribution list management script"

# Function to create a new distribution list
function New-CustomDistributionList {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$DisplayName,
        
        [string]$Description = "",
        
        [string]$ManagerDN = "",
        
        [string]$OrganizationalUnit = "OU=Distribution Lists,DC=contoso,DC=com",
        
        [string[]]$InitialMembers = @(),
        
        [bool]$MailEnabled = $true
    )
    
    try {
        # Create the group
        $groupParams = @{
            Name = $Name
            DisplayName = $DisplayName
            Description = $Description
            GroupCategory = "Distribution"
            GroupScope = "Universal"
            Path = $OrganizationalUnit
        }
        
        $newGroup = New-ADGroup @groupParams -PassThru
        Write-Host "Created distribution list: $Name"
        
        # Set manager if specified
        if ($ManagerDN -ne "") {
            Set-ADGroup -Identity $newGroup -ManagedBy $ManagerDN
            Write-Host "Set manager for $Name to $ManagerDN"
        }
        
        # Add initial members
        if ($InitialMembers.Count -gt 0) {
            Add-ADGroupMember -Identity $newGroup -Members $InitialMembers
            Write-Host "Added $($InitialMembers.Count) initial members to $Name"
        }
        
        # Mail-enable the group if required
        # This requires Exchange Management Shell
        if ($MailEnabled) {
            try {
                # Check if Exchange cmdlets are available
                if (Get-Command Enable-DistributionGroup -ErrorAction SilentlyContinue) {
                    Enable-DistributionGroup -Identity $newGroup.DistinguishedName
                    Write-Host "Mail-enabled distribution list: $Name"
                    
                    # Set email address if needed
                    $emailAddress = "$Name@contoso.com"
                    Set-DistributionGroup -Identity $newGroup.DistinguishedName -PrimarySmtpAddress $emailAddress
                    Write-Host "Set email address for $Name to $emailAddress"
                }
                else {
                    Write-Warning "Exchange cmdlets not available. Distribution list created but not mail-enabled."
                }
            }
            catch {
                Write-Warning "Failed to mail-enable group. Error: $_"
            }
        }
        
        return $newGroup
    }
    catch {
        Write-Error "Failed to create distribution list $Name. Error: $_"
        return $null
    }
}

# Function to update distribution list from CSV
function Update-DistributionListFromCSV {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CsvPath
    )
    
    if (-not (Test-Path $CsvPath)) {
        Write-Error "CSV file not found: $CsvPath"
        return
    }
    
    $dlLists = Import-Csv -Path $CsvPath
    
    foreach ($dl in $dlLists) {
        # Check if required fields exist
        if (-not ($dl.Name -and $dl.DisplayName)) {
            Write-Warning "Missing required fields for a distribution list in CSV. Skipping."
            continue
        }
        
        # Check if the group exists
        $existingGroup = Get-ADGroup -Filter "Name -eq '$($dl.Name)'" -ErrorAction SilentlyContinue
        
        if ($existingGroup) {
            Write-Host "Updating existing distribution list: $($dl.Name)"
            
            # Update description if provided
            if ($dl.Description) {
                Set-ADGroup -Identity $existingGroup -Description $dl.Description
            }
            
            # Update manager if provided
            if ($dl.Manager) {
                $manager = Get-ADUser -Filter "SamAccountName -eq '$($dl.Manager)'" -ErrorAction SilentlyContinue
                if ($manager) {
                    Set-ADGroup -Identity $existingGroup -ManagedBy $manager
                    Write-Host "Updated manager for $($dl.Name) to $($dl.Manager)"
                }
                else {
                    Write-Warning "Manager $($dl.Manager) not found for group $($dl.Name)"
                }
            }
            
            # Update members if provided (comma-separated list)
            if ($dl.Members) {
                $members = $dl.Members -split ','
                $currentMembers = Get-ADGroupMember -Identity $existingGroup | Select-Object -ExpandProperty SamAccountName
                
                # Add new members
                foreach ($member in $members) {
                    $member = $member.Trim()
                    if ($member -and $member -notin $currentMembers) {
                        try {
                            $adUser = Get-ADUser -Filter "SamAccountName -eq '$member'" -ErrorAction Stop
                            Add-ADGroupMember -Identity $existingGroup -Members $adUser
                            Write-Host "Added member $member to $($dl.Name)"
                        }
                        catch {
                            Write-Warning "Failed to add member $member to $($dl.Name). Error: $_"
                        }
                    }
                }
                
                # Remove members no longer in the list
                foreach ($currentMember in $currentMembers) {
                    if ($currentMember -notin $members) {
                        try {
                            $adUser = Get-ADUser -Identity $currentMember -ErrorAction Stop
                            Remove-ADGroupMember -Identity $existingGroup -Members $adUser -Confirm:$false
                            Write-Host "Removed member $currentMember from $($dl.Name)"
                        }
                        catch {
                            Write-Warning "Failed to remove member $currentMember from $($dl.Name). Error: $_"
                        }
                    }
                }
            }
        }
        else {
            # Create new distribution list
            Write-Host "Creating new distribution list: $($dl.Name)"
            
            $ou = if ($dl.OU) { $dl.OU } else { "OU=Distribution Lists,DC=contoso,DC=com" }
            $members = if ($dl.Members) { ($dl.Members -split ',').Trim() } else { @() }
            
            $manager = $null
            if ($dl.Manager) {
                $manager = Get-ADUser -Filter "SamAccountName -eq '$($dl.Manager)'" -ErrorAction SilentlyContinue
                if (-not $manager) {
                    Write-Warning "Manager $($dl.Manager) not found for new group $($dl.Name)"
                }
            }
            
            # Convert member names to AD user objects
            $memberObjects = @()
            foreach ($member in $members) {
                try {
                    $adUser = Get-ADUser -Filter "SamAccountName -eq '$member'" -ErrorAction Stop
                    $memberObjects += $adUser
                }
                catch {
                    Write-Warning "User $member not found for new group $($dl.Name)"
                }
            }
            
            New-CustomDistributionList -Name $dl.Name -DisplayName $dl.DisplayName -Description $dl.Description `
                -ManagerDN $manager.DistinguishedName -OrganizationalUnit $ou -InitialMembers $memberObjects
        }
    }
}

# Get all distribution lists and generate report
function Get-DistributionListReport {
    param (
        [string]$OutputPath = $reportPath
    )
    
    $distributionGroups = Get-ADGroup -Filter 'GroupCategory -eq "Distribution"' -Properties DisplayName, Description, ManagedBy, mail, whenCreated, whenChanged
    
    $report = @()
    
    foreach ($group in $distributionGroups) {
        $members = Get-ADGroupMember -Identity $group -ErrorAction SilentlyContinue
        $memberCount = if ($members) { $members.Count } else { 0 }
        
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
        
        $report += [PSCustomObject]@{
            Name = $group.Name
            DisplayName = $group.DisplayName
            Description = $group.Description
            Manager = $managerName
            ManagerDN = $group.ManagedBy
            EmailAddress = $group.mail
            MemberCount = $memberCount
            Created = $group.whenCreated
            LastChanged = $group.whenChanged
        }
    }
    
    $report | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "Distribution list report exported to $OutputPath"
    
    return $report
}

# Main execution
try {
    # Generate report of all distribution lists
    $dlReport = Get-DistributionListReport
    Write-Host "Found $($dlReport.Count) distribution lists in Active Directory"
    
    # If a CSV file exists, update distribution lists from it
    if (Test-Path $dlListFile) {
        Write-Host "Found distribution list management file, updating groups from CSV"
        Update-DistributionListFromCSV -CsvPath $dlListFile
    }
    else {
        Write-Host "No distribution list CSV file found at $dlListFile"
        Write-Host "Sample CSV format:"
        Write-Host "Name,DisplayName,Description,Manager,Members,OU"
        Write-Host "Marketing,Marketing Team,Marketing communications,jsmith,jsmith;adavis;mwilson,OU=Groups,DC=contoso,DC=com"
    }
    
    # Optionally create a template CSV
    $templatePath = "C:\ADScripts\Templates\DistributionListTemplate.csv"
    $templateDir = Split-Path $templatePath -Parent
    if (-not (Test-Path $templateDir)) { New-Item -Path $templateDir -ItemType Directory -Force }
    
    @"
Name,DisplayName,Description,Manager,Members,OU
Marketing,Marketing Team,Marketing department communications,jsmith,jsmith;adavis;mwilson,OU=Distribution Lists,DC=contoso,DC=com
HR,Human Resources,HR announcements,hmanager,hmanager;hrep1;hrep2,OU=Distribution Lists,DC=contoso,DC=com
"@ | Out-File -FilePath $templatePath -Force
    
    Write-Host "Distribution list template saved to $templatePath"
}
catch {
    Write-Error "An error occurred during distribution list management: $_"
}

Stop-Transcript
