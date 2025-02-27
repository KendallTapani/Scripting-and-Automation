# Computer OU Organization Script
# This script moves computer accounts to appropriate OUs based on naming conventions or other attributes

# Parameters
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "C:\Scripts\ComputerOUConfig.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $true, # Default to WhatIf mode (no actual moves)
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\ComputerOUOrganization_$(Get-Date -Format 'yyyyMMdd').log"
)

# Import required modules
Import-Module ActiveDirectory

# Start logging
Start-Transcript -Path $LogPath -Append
Write-Output "Script started at $(Get-Date)"

# Check if configuration file exists
if (-not (Test-Path -Path $ConfigPath)) {
    Write-Error "Configuration file not found at $ConfigPath"
    Write-Output "Creating sample configuration file at $ConfigPath"
    
    # Create sample configuration
    $SampleConfig = @{
        "Rules" = @(
            @{
                "Name" = "Laptops Rule"
                "Type" = "NamePattern"
                "Pattern" = "^LT-"
                "TargetOU" = "OU=Laptops,OU=Computers,DC=contoso,DC=com"
                "Priority" = 1
            },
            @{
                "Name" = "Desktops Rule"
                "Type" = "NamePattern"
                "Pattern" = "^DT-"
                "TargetOU" = "OU=Desktops,OU=Computers,DC=contoso,DC=com"
                "Priority" = 2
            },
            @{
                "Name" = "Finance Department Rule"
                "Type" = "NamePattern"
                "Pattern" = "-FIN-"
                "TargetOU" = "OU=Finance,OU=Departments,OU=Computers,DC=contoso,DC=com"
                "Priority" = 3
            },
            @{
                "Name" = "Engineering Department Rule"
                "Type" = "NamePattern"
                "Pattern" = "-ENG-"
                "TargetOU" = "OU=Engineering,OU=Departments,OU=Computers,DC=contoso,DC=com"
                "Priority" = 4
            },
            @{
                "Name" = "Windows 10 Rule"
                "Type" = "OperatingSystem"
                "Pattern" = "Windows 10*"
                "TargetOU" = "OU=Win10,OU=Computers,DC=contoso,DC=com"
                "Priority" = 10 # Lower priority, will only apply if no other rules match
            }
        )
    }
    
    # Create the directory for the config if it doesn't exist
    $ConfigDirectory = Split-Path -Path $ConfigPath -Parent
    if (-not (Test-Path -Path $ConfigDirectory)) {
        New-Item -ItemType Directory -Path $ConfigDirectory -Force | Out-Null
    }
    
    # Save the sample configuration
    $SampleConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $ConfigPath
    
    Write-Output "Please update the configuration file with your actual OU structure and naming conventions."
    Write-Output "Then run this script again."
    Stop-Transcript
    exit
}

# Load the configuration
try {
    $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    Write-Output "Configuration loaded from $ConfigPath"
    Write-Output "Found $($Config.Rules.Count) rules for organizing computers"
}
catch {
    Write-Error "Failed to load configuration: $_"
    Stop-Transcript
    exit
}

# Get all computer accounts with properties
$Computers = Get-ADComputer -Filter * -Properties Name, OperatingSystem, Description, DistinguishedName

Write-Output "Retrieved $($Computers.Count) computer accounts from Active Directory"

# Sort rules by priority
$SortedRules = $Config.Rules | Sort-Object -Property Priority

# Process each computer
$MovedCount = 0
$NoMatchCount = 0
$AlreadyInPlaceCount = 0
$ErrorCount = 0

foreach ($Computer in $Computers) {
    $MatchFound = $false
    $CurrentOU = ($Computer.DistinguishedName -split ',', 2)[1]
    
    # Check each rule until a match is found
    foreach ($Rule in $SortedRules) {
        $Match = $false
        
        # Check the rule type and apply matching logic
        switch ($Rule.Type) {
            "NamePattern" {
                if ($Computer.Name -match $Rule.Pattern) {
                    $Match = $true
                }
            }
            "OperatingSystem" {
                if ($Computer.OperatingSystem -like $Rule.Pattern) {
                    $Match = $true
                }
            }
            # Add additional rule types as needed
        }
        
        # If this rule matches, process the computer
        if ($Match) {
            $MatchFound = $true
            $TargetOU = $Rule.TargetOU
            
            # Check if the computer is already in the correct OU
            if ($CurrentOU -eq $TargetOU) {
                Write-Verbose "Computer $($Computer.Name) is already in the correct OU: $TargetOU"
                $AlreadyInPlaceCount++
            }
            else {
                # Move the computer to the target OU
                try {
                    if (-not $WhatIf) {
                        Move-ADObject -Identity $Computer.DistinguishedName -TargetPath $TargetOU
                        Write-Output "Moved computer $($Computer.Name) to $TargetOU (Rule: $($Rule.Name))"
                    }
                    else {
                        Write-Output "WhatIf: Would move computer $($Computer.Name) to $TargetOU (Rule: $($Rule.Name))"
                    }
                    $MovedCount++
                }
                catch {
                    Write-Error "Failed to move computer $($Computer.Name): $_"
                    $ErrorCount++
                }
            }
            
            # Stop checking rules after the first match
            break
        }
    }
    
    # If no rule matched this computer
    if (-not $MatchFound) {
        Write-Warning "No matching rule found for computer $($Computer.Name)"
        $NoMatchCount++
    }
}

# Output summary statistics
Write-Output "=== Organization Summary ==="
Write-Output "Total computers processed: $($Computers.Count)"
if ($WhatIf) {
    Write-Output "Computers that would be moved: $MovedCount"
}
else {
    Write-Output "Computers moved: $MovedCount"
}
Write-Output "Computers already in correct OU: $AlreadyInPlaceCount"
Write-Output "Computers with no matching rule: $NoMatchCount"
Write-Output "Errors encountered: $ErrorCount"
Write-Output "==========================="

if ($WhatIf) {
    Write-Output "Script ran in WhatIf mode. No actual changes were made."
    Write-Output "Run with -WhatIf:`$false to apply changes."
}

Write-Output "Script completed at $(Get-Date)"
Stop-Transcript

# Examples of how to use this script:
# 
# 1. WhatIf Mode (default) - Shows what would happen but makes no changes
# .\ComputerOUOrganization.ps1
# 
# 2. Apply Mode - Actually moves computers to target OUs
# .\ComputerOUOrganization.ps1 -WhatIf:$false
# 
# 3. Custom configuration file
# .\ComputerOUOrganization.ps1 -ConfigPath "D:\Config\MyOrgRules.json"
