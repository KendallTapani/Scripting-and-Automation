#Requires -Version 5.1
#Requires -Modules ActiveDirectory
#Requires -RunAsAdministrator


[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$Username,
    
    [Parameter(Mandatory = $false)]
    [string]$DelegateAccessTo,
    
    [Parameter(Mandatory = $false)]
    [bool]$PreserveMailbox = $false,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Voluntary", "Involuntary", "Retirement")]
    [string]$TerminationType = "Voluntary"
)

# Configuration variables - Edit these for your environment
$DisabledUsersOU = "OU=Disabled Users,DC=contoso,DC=com"
$ArchiveShare = "\\fileserver01\UserArchives"
$LogPath = "C:\Logs\UserOffboarding"
$RetentionPeriod = 90 # Days to keep account before potential deletion

# Create log directory if it doesn't exist
if (-not (Test-Path -Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Start transcript logging
$LogFile = Join-Path -Path $LogPath -ChildPath "Offboarding_$Username`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogFile -Append

try {
    Write-Host "Starting offboarding process for user: $Username" -ForegroundColor Yellow
    
    # Verify user exists
    try {
        $User = Get-ADUser -Identity $Username -Properties MemberOf, HomeDirectory, Manager, DisplayName, Department, Title, Description, Mail, EmployeeID -ErrorAction Stop
        Write-Host "User $Username ($($User.DisplayName)) found" -ForegroundColor Cyan
    }
    catch {
        throw "User $Username not found in Active Directory. Please provide a valid username."
    }
    
    # Backup user information
    $UserInfo = @{
        "Username" = $Username
        "DisplayName" = $User.DisplayName
        "Department" = $User.Department
        "Title" = $User.Title
        "Email" = $User.Mail
        "Manager" = $(if ($User.Manager) { (Get-ADUser -Identity $User.Manager).SamAccountName } else { "None" })
        "EmployeeID" = $User.EmployeeID
        "HomeDirectory" = $User.HomeDirectory
        "OffboardingDate" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "OffboardingType" = $TerminationType
        "DisabledBy" = $env:USERNAME
    }
    
    $BackupFile = Join-Path -Path $LogPath -ChildPath "OffboardingInfo_$Username.xml"
    $UserInfo | Export-Clixml -Path $BackupFile
    Write-Host "User information backed up to $BackupFile" -ForegroundColor Cyan
    
    # Backup group memberships
    $Groups = $User.MemberOf | ForEach-Object { Get-ADGroup -Identity $_ }
    $GroupNames = $Groups | Select-Object -ExpandProperty Name
    
    $GroupsFile = Join-Path -Path $LogPath -ChildPath "Groups_$Username.txt"
    $GroupNames | Out-File -FilePath $GroupsFile
    Write-Host "Group memberships backed up to $GroupsFile" -ForegroundColor Cyan
    
    # Create a random, complex password to set on the account
    $NewPassword = [System.Web.Security.Membership]::GeneratePassword(16, 5)
    $SecurePassword = ConvertTo-SecureString -String $NewPassword -AsPlainText -Force
    
    # Get current date for description update
    $CurrentDate = Get-Date -Format "yyyy-MM-dd"
    $NewDescription = "DISABLED $CurrentDate - $TerminationType Termination - Previously: $($User.Description)"
    
    # Disable user account and update properties
    Set-ADAccountPassword -Identity $Username -NewPassword $SecurePassword -Reset
    Set-ADUser -Identity $Username -Enabled $false -Description $NewDescription
    Write-Host "User account disabled and password randomized" -ForegroundColor Green
    
    # Remove from all groups except Domain Users (which cannot be removed)
    foreach ($Group in $Groups) {
        if ($Group.Name -ne "Domain Users") {
            Remove-ADGroupMember -Identity $Group -Members $Username -Confirm:$false
            Write-Host "Removed from group: $($Group.Name)" -ForegroundColor Cyan
        }
    }
    Write-Host "Removed user from all groups" -ForegroundColor Green
    
    # Move to Disabled Users OU
    if (Test-Path -Path "AD:\$DisabledUsersOU" -PathType Container) {
        Move-ADObject -Identity $User.DistinguishedName -TargetPath $DisabledUsersOU
        Write-Host "Moved user to Disabled Users OU" -ForegroundColor Green
    }
    else {
        Write-Warning "Disabled Users OU not found. User will remain in current OU."
    }
    
    # Hide from Global Address List (if applicable to your environment)
    # Note: This requires Exchange Management tools or Exchange Web Services
    # Uncomment and modify based on your environment
    <#
    $ExchangeServer = "exchange01"
    $ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExchangeServer/PowerShell/" -Authentication Kerberos
    Import-PSSession $ExchangeSession -DisableNameChecking -AllowClobber
    
    Set-Mailbox -Identity $Username -HiddenFromAddressListsEnabled $true
    
    Remove-PSSession $ExchangeSession
    #>
    
    # Handle home directory
    if ($User.HomeDirectory -and (Test-Path -Path $User.HomeDirectory)) {
        $HomeDir = $User.HomeDirectory
        $Username = $User.SamAccountName
        $ArchiveDir = Join-Path -Path $ArchiveShare -ChildPath $Username
        
        # Create archive directory if it doesn't exist
        if (-not (Test-Path -Path $ArchiveDir)) {
            New-Item -Path $ArchiveDir -ItemType Directory -Force | Out-Null
        }
        
        # Handle access delegation if requested
        if ($DelegateAccessTo) {
            try {
                $Delegate = Get-ADUser -Identity $DelegateAccessTo -ErrorAction Stop
                
                # Get current ACL
                $Acl = Get-Acl -Path $HomeDir
                
                # Add delegate with Read permissions
                $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    "$($env:USERDOMAIN)\$($Delegate.SamAccountName)", 
                    "ReadAndExecute", 
                    "ContainerInherit,ObjectInherit", 
                    "None", 
                    "Allow"
                )
                $Acl.AddAccessRule($AccessRule)
                
                # Remove user's permissions
                $UserAccessRules = $Acl.Access | Where-Object { $_.IdentityReference -like "*$Username*" }
                foreach ($Rule in $UserAccessRules) {
                    $Acl.RemoveAccessRule($Rule)
                }
                
                # Apply the new ACL
                Set-Acl -Path $HomeDir -AclObject $Acl
                
                Write-Host "Delegated access to $($Delegate.SamAccountName) for user's home directory" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to delegate access: $_"
            }
        }
        
        # Create an archive task to run after the retention period
        $ArchiveScriptContent = @"
# Archive script for $Username
`$SourcePath = "$HomeDir"
`$DestinationPath = "$ArchiveDir"

# Check if source exists
if (Test-Path -Path `$SourcePath) {
    # Copy all files to archive
    robocopy `$SourcePath `$DestinationPath /E /COPY:DAT /R:3 /W:5
    
    # If copy successful, mark the original folder as to be deleted
    if (`$LASTEXITCODE -lt 8) {
        Rename-Item -Path `$SourcePath -NewName "`$(`$SourcePath)_TO_DELETE"
    }
}
"@
        
        $ArchiveScriptPath = Join-Path -Path $LogPath -ChildPath "Archive_$Username.ps1"
        $ArchiveScriptContent | Out-File -FilePath $ArchiveScriptPath
        
        # Schedule the archive task to run after retention period
        $ActionParams = @{
            Execute = "powershell.exe"
            Argument = "-ExecutionPolicy Bypass -File `"$ArchiveScriptPath`""
        }
        
        $TriggerParams = @{
            Once = $true
            At = (Get-Date).AddDays($RetentionPeriod)
        }
        
        $TaskName = "Archive_User_$Username"
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        $Action = New-ScheduledTaskAction @ActionParams
        $Trigger = New-ScheduledTaskTrigger @TriggerParams
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
        
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Archive home directory for offboarded user $Username"
        
        Write-Host "Scheduled archive task for $RetentionPeriod days from now" -ForegroundColor Cyan
    }
    else {
        Write-Warning "Home directory not found or not accessible. Skipping home directory archiving."
    }
    
    # Generate offboarding report
    $OffboardingReport = @{
        "Username" = $Username
        "Display Name" = $User.DisplayName
        "Department" = $User.Department
        "Offboarding Date" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "Offboarding Type" = $TerminationType
        "Performed By" = $env:USERNAME
        "Account Status" = "Disabled"
        "File Access Delegated To" = if ($DelegateAccessTo) { $DelegateAccessTo } else { "None" }
        "Home Directory" = $User.HomeDirectory
        "Archive Scheduled For" = (Get-Date).AddDays($RetentionPeriod).ToString("yyyy-MM-dd")
    }
    
    $ReportFile = Join-Path -Path $LogPath -ChildPath "OffboardingReport_$Username.csv"
    $OffboardingReport | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $ReportFile
    
    Write-Host "Offboarding process completed successfully for $Username" -ForegroundColor Green
    Write-Host "Offboarding report saved to: $ReportFile" -ForegroundColor Cyan
    
    # Optional: Send email notification to IT
    # This requires Exchange Online or on-premises Exchange configuration
    <#
    Send-MailMessage -To "it@contoso.com" `
                    -From "itsystem@contoso.com" `
                    -Subject "User Account Offboarded: $($User.DisplayName)" `
                    -Body "User account for $($User.DisplayName) has been offboarded. Please see the attached report for details." `
                    -Attachments $ReportFile `
                    -SmtpServer "smtp.contoso.com"
    #>
    
    # Return offboarding information
    return $OffboardingReport
}
catch {
    Write-Host "Error during offboarding process: $_" -ForegroundColor Red
    throw $_
}
finally {
    # Stop transcript logging
    Stop-Transcript
}
