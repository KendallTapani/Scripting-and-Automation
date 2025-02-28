# Permission Auditing for Sensitive AD Objects
# This script audits permissions on sensitive AD objects and outputs a report

# Import required modules
Import-Module ActiveDirectory

# Function to get ACL information for AD objects
function Get-ADObjectPermissions {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ADObjectDN
    )
    
    $acl = Get-Acl -Path "AD:\$ADObjectDN"
    
    $permissions = @()
    foreach ($access in $acl.Access) {
        $permissions += [PSCustomObject]@{
            IdentityReference = $access.IdentityReference
            AccessControlType = $access.AccessControlType
            ActiveDirectoryRights = $access.ActiveDirectoryRights
            InheritanceType = $access.InheritanceType
            ObjectType = $access.ObjectType
            InheritedObjectType = $access.InheritedObjectType
        }
    }
    
    return $permissions
}

# Define sensitive objects to audit (customize as needed)
$sensitiveObjects = @(
    (Get-ADDomain).DistinguishedName,                             # Domain root
    "CN=Admins,OU=Groups,$(Get-ADDomain -Current LocalComputer)", # Admin groups
    "OU=Finance,OU=Departments,$(Get-ADDomain -Current LocalComputer)", # Finance OU
    "OU=HR,OU=Departments,$(Get-ADDomain -Current LocalComputer)",      # HR OU
    "CN=AdminSDHolder,CN=System,$(Get-ADDomain -Current LocalComputer)" # AdminSDHolder
)

# Set output file path
$outputPath = "C:\Reports\PermissionAudit_$(Get-Date -Format 'yyyy-MM-dd').csv"

# Create output directory if it doesn't exist
$outputDir = Split-Path -Path $outputPath -Parent
if (-not (Test-Path -Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force
}

# Initialize results array
$results = @()

# Audit each sensitive object
foreach ($object in $sensitiveObjects) {
    Write-Host "Auditing permissions for $object"
    try {
        $permissions = Get-ADObjectPermissions -ADObjectDN $object
        
        foreach ($permission in $permissions) {
            $results += [PSCustomObject]@{
                Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Object = $object
                IdentityReference = $permission.IdentityReference
                AccessControlType = $permission.AccessControlType
                ActiveDirectoryRights = $permission.ActiveDirectoryRights
                InheritanceType = $permission.InheritanceType
                ObjectType = $permission.ObjectType
                InheritedObjectType = $permission.InheritedObjectType
            }
        }
    }
    catch {
        Write-Warning "Error auditing $object : $_"
    }
}

# Export results to CSV
$results | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "Permission audit completed. Report saved to $outputPath"

# Optional: Send email with report
<# 
$emailParams = @{
    SmtpServer = 'smtp.yourdomain.com'
    From = 'security@yourdomain.com'
    To = 'admin@yourdomain.com'
    Subject = "Permission Audit Report - $(Get-Date -Format 'yyyy-MM-dd')"
    Body = "Please find attached the permission audit report for sensitive AD objects."
    Attachments = $outputPath
}
Send-MailMessage @emailParams
#>
