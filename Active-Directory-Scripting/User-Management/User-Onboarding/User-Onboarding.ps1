#Requires -Version 5.1
#Requires -Modules ActiveDirectory
#Requires -RunAsAdministrator


[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$FirstName,
    
    [Parameter(Mandatory = $true)]
    [string]$LastName,
    
    [Parameter(Mandatory = $true)]
    [string]$Department,
    
    [Parameter(Mandatory = $true)]
    [string]$Title,
    
    [Parameter(Mandatory = $true)]
    [string]$Manager,
    
    [Parameter(Mandatory = $false)]
    [string]$Template
)

# Configuration variables - Edit these for your environment
$DomainName = "contoso.com"
$UPNSuffix = "contoso.com"
$HomeShareServer = "\\fileserver01"
$HomeShareRoot = "UserHomes"
$DefaultPassword = "Temp" + (Get-Random -Minimum 100000 -Maximum 999999) + "!"
$PasswordNeverExpires = $false
$MustChangePasswordAtNextLogon = $true
$OUPath = "OU=$Department,OU=Users,DC=contoso,DC=com"
$LogPath = "C:\Logs\UserOnboarding"
$EmailDomain = "contoso.com"

# Create log directory if it doesn't exist
if (-not (Test-Path -Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Start transcript logging
$LogFile = Join-Path -Path $LogPath -ChildPath "Onboarding_$($FirstName)_$($LastName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogFile -Append

# Function to create the username based on standard naming convention
function Get-NewUsername {
    param (
        [string]$FirstName,
        [string]$LastName
    )
    
    # Standard username format: first initial + last name (all lowercase)
    $username = ($FirstName.Substring(0, 1) + $LastName).ToLower()
    
    # Check if username already exists and append number if needed
    $counter = 1
    $originalUsername = $username
    
    while (Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue) {
        $username = $originalUsername + $counter
        $counter++
    }
    
    return $username
}

try {
    Write-Host "Starting onboarding process for $FirstName $LastName" -ForegroundColor Green
    
    # Generate username
    $Username = Get-NewUsername -FirstName $FirstName -LastName $LastName
    $DisplayName = "$FirstName $LastName"
    $UserPrincipalName = "$Username@$UPNSuffix"
    $EmailAddress = "$Username@$EmailDomain"
    
    Write-Host "Generated username: $Username" -ForegroundColor Cyan
    
    # Verify manager exists
    try {
        $ManagerAccount = Get-ADUser -Identity $Manager -ErrorAction Stop
        Write-Host "Manager $Manager verified" -ForegroundColor Cyan
    }
    catch {
        throw "Manager $Manager not found in Active Directory. Please provide a valid manager username."
    }
    
    # Ensure OU exists
    try {
        Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop | Out-Null
        Write-Host "Organizational Unit $OUPath verified" -ForegroundColor Cyan
    }
    catch {
        throw "OU $OUPath does not exist. Please ensure the OU is created or provide a valid OU path."
    }
    
    # Create new user account in AD
    $NewUserParams = @{
        SamAccountName = $Username
        UserPrincipalName = $UserPrincipalName
        Name = $DisplayName
        GivenName = $FirstName
        Surname = $LastName
        DisplayName = $DisplayName
        Title = $Title
        Department = $Department
        EmailAddress = $EmailAddress
        Manager = $ManagerAccount
        Enabled = $true
        PasswordNeverExpires = $PasswordNeverExpires
        ChangePasswordAtLogon = $MustChangePasswordAtNextLogon
        AccountPassword = (ConvertTo-SecureString -String $DefaultPassword -AsPlainText -Force)
        Path = $OUPath
    }
    
    New-ADUser @NewUserParams
    Write-Host "Created new AD user account for $DisplayName" -ForegroundColor Green
    
    # Create home directory
    $HomePath = "$HomeShareServer\$HomeShareRoot\$Username"
    if (-not (Test-Path -Path $HomePath)) {
        New-Item -Path $HomePath -ItemType Directory -Force | Out-Null
        
        # Set NTFS permissions on home directory
        $Acl = Get-Acl -Path $HomePath
        $UserIdentity = "$DomainName\$Username"
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($UserIdentity, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
        $Acl.AddAccessRule($AccessRule)
        Set-Acl -Path $HomePath -AclObject $Acl
        
        Write-Host "Created home directory for $Username at $HomePath" -ForegroundColor Cyan
        
        # Update user's home directory in AD
        Set-ADUser -Identity $Username -HomeDrive "H:" -HomeDirectory $HomePath
        Write-Host "Set home directory mapping for $Username" -ForegroundColor Cyan
    }
    else {
        Write-Warning "Home directory $HomePath already exists. Skipping directory creation."
    }
    
    # Add user to groups based on template user or default groups for department
    if ($Template) {
        try {
            $TemplateUser = Get-ADUser -Identity $Template -Properties MemberOf -ErrorAction Stop
            $Groups = $TemplateUser.MemberOf
            
            foreach ($Group in $Groups) {
                Add-ADGroupMember -Identity $Group -Members $Username
            }
            
            Write-Host "Added $Username to groups based on template user $Template" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "Template user $Template not found or error adding to groups: $_"
        }
    }
    else {
        # Add to department default groups
        # This section should be customized based on your organization's structure
        try {
            $DepartmentGroups = @{
                "IT" = @("IT Department", "VPN Users", "Remote Desktop Users")
                "HR" = @("HR Department", "Employee Records")
                "Finance" = @("Finance Department", "Accounting")
                "Sales" = @("Sales Department", "CRM Users")
                "Marketing" = @("Marketing Department", "Creative Team")
                # Add more departments as needed
            }
            
            if ($DepartmentGroups.ContainsKey($Department)) {
                foreach ($Group in $DepartmentGroups[$Department]) {
                    Add-ADGroupMember -Identity $Group -Members $Username -ErrorAction SilentlyContinue
                }
                Write-Host "Added $Username to default groups for $Department department" -ForegroundColor Cyan
            }
            
            # Add to general groups that all users should belong to
            $CommonGroups = @("All Users", "Internet Access")
            foreach ($Group in $CommonGroups) {
                Add-ADGroupMember -Identity $Group -Members $Username -ErrorAction SilentlyContinue
            }
            Write-Host "Added $Username to common groups" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "Error adding to department groups: $_"
        }
    }
    
    # Generate onboarding report
    $OnboardingReport = @{
        "Username" = $Username
        "Display Name" = $DisplayName
        "Email Address" = $EmailAddress
        "Department" = $Department
        "Title" = $Title
        "Manager" = $Manager
        "Temporary Password" = $DefaultPassword
        "Home Directory" = $HomePath
        "Creation Date" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    
    $ReportFile = Join-Path -Path $LogPath -ChildPath "OnboardingReport_$Username.csv"
    $OnboardingReport | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $ReportFile
    
    Write-Host "Onboarding process completed successfully for $DisplayName" -ForegroundColor Green
    Write-Host "Temporary password: $DefaultPassword" -ForegroundColor Yellow
    Write-Host "Onboarding report saved to: $ReportFile" -ForegroundColor Cyan
    
    # Optional: Send email notification to IT and manager
    # This requires Exchange Online or on-premises Exchange configuration
    <#
    Send-MailMessage -To "it@contoso.com","$Manager@contoso.com" `
                    -From "itsystem@contoso.com" `
                    -Subject "New User Account Created: $DisplayName" `
                    -Body "A new user account has been created for $DisplayName. Please see the attached report for details." `
                    -Attachments $ReportFile `
                    -SmtpServer "smtp.contoso.com"
    #>
    
    # Return user information
    return @{
        Username = $Username
        DisplayName = $DisplayName
        Email = $EmailAddress
        TemporaryPassword = $DefaultPassword
    }
}
catch {
    Write-Host "Error during onboarding process: $_" -ForegroundColor Red
    throw $_
}
finally {
    # Stop transcript logging
    Stop-Transcript
}
