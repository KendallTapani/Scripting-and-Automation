# Import necessary modules
Import-Module ActiveDirectory

# Function to generate a strong random password
function New-ComplexPassword {
    param (
        [int]$Length = 16,
        [int]$SpecialChars = 3,
        [int]$Digits = 3
    )
    
    # Define character sets
    $Lowercase = 'abcdefghijklmnopqrstuvwxyz'
    $Uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $Numbers = '0123456789'
    $Special = '!@#$%^&*()-_=+[]{}|;:,.<>?'
    
    # Start with required number of random special characters
    $Password = ''
    for ($i = 0; $i -lt $SpecialChars; $i++) {
        $Password += $Special[(Get-Random -Maximum $Special.Length)]
    }
    
    # Add required number of random digits
    for ($i = 0; $i -lt $Digits; $i++) {
        $Password += $Numbers[(Get-Random -Maximum $Numbers.Length)]
    }
    
    # Add at least one uppercase letter
    $Password += $Uppercase[(Get-Random -Maximum $Uppercase.Length)]
    
    # Add at least one lowercase letter
    $Password += $Lowercase[(Get-Random -Maximum $Lowercase.Length)]
    
    # Fill the rest with random letters (mix of upper and lower)
    $RemainingLength = $Length - $Password.Length
    for ($i = 0; $i -lt $RemainingLength; $i++) {
        if (Get-Random -Maximum 2) {
            $Password += $Uppercase[(Get-Random -Maximum $Uppercase.Length)]
        } else {
            $Password += $Lowercase[(Get-Random -Maximum $Lowercase.Length)]
        }
    }
    
    # Shuffle the password characters
    $Password = -join ($Password.ToCharArray() | Get-Random -Count $Password.Length)
    
    return $Password
}

# Function to log password changes to a secure file
function Write-PasswordChangeLog {
    param (
        [string]$Username,
        [string]$Password,
        [string]$LogFile = "C:\Logs\ServiceAccount_Passwords.csv"
    )
    
    # Create directory if it doesn't exist
    $LogDir = Split-Path -Path $LogFile -Parent
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    # Encrypt the password for storage
    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $EncryptedPassword = ConvertFrom-SecureString -SecureString $SecurePassword
    
    # Format log entry
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = [PSCustomObject]@{
        Timestamp = $Timestamp
        Username = $Username
        EncryptedPassword = $EncryptedPassword
    }
    
    # Write to log file in CSV format
    $LogEntry | Export-Csv -Path $LogFile -Append -NoTypeInformation
}

# Function to update a service account password
function Update-ServiceAccountPassword {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServiceAccount,
        
        [Parameter(Mandatory=$false)]
        [string]$NewPassword = "",
        
        [Parameter(Mandatory=$false)]
        [bool]$GenerateRandom = $true,
        
        [Parameter(Mandatory=$false)]
        [int]$PasswordLength = 16,
        
        [Parameter(Mandatory=$false)]
        [bool]$LogPassword = $true,
        
        [Parameter(Mandatory=$false)]
        [string]$LogFile = "C:\Logs\ServiceAccount_Passwords.csv",
        
        [Parameter(Mandatory=$false)]
        [string[]]$ServersToUpdate = @()
    )
    
    try {
        # Generate random password if requested or if no password provided
        if ($GenerateRandom -or [string]::IsNullOrEmpty($NewPassword)) {
            $NewPassword = New-ComplexPassword -Length $PasswordLength
        }
        
        # Convert password to secure string
        $SecurePassword = ConvertTo-SecureString -String $NewPassword -AsPlainText -Force
        
        # Reset the password in AD
        Set-ADAccountPassword -Identity $ServiceAccount -NewPassword $SecurePassword -Reset
        
        # Log the action with encrypted password
        if ($LogPassword) {
            Write-PasswordChangeLog -Username $ServiceAccount -Password $NewPassword -LogFile $LogFile
        }
        
        # Output information
        Write-Host "Password for service account '$ServiceAccount' has been updated successfully." -ForegroundColor Green
        
        # If servers are specified, update the service password on those servers
        if ($ServersToUpdate.Count -gt 0) {
            Write-Host "Updating services on specified servers..." -ForegroundColor Yellow
            
            foreach ($Server in $ServersToUpdate) {
                try {
                    # Connect to the server and find services using this account
                    $Services = Get-WmiObject -Class Win32_Service -ComputerName $Server | 
                                Where-Object { $_.StartName -like "*$ServiceAccount*" }
                    
                    if ($Services) {
                        foreach ($Service in $Services) {
                            try {
                                # Change the service password
                                $Service.Change($null, $null, $null, $null, $null, $null, $null, $NewPassword, $null, $null, $null)
                                Write-Host "Updated password for service '$($Service.Name)' on server '$Server'" -ForegroundColor Green
                                
                                # Restart the service if it's running
                                if ($Service.State -eq "Running") {
                                    $RestartConfirm = Read-Host "Service '$($Service.Name)' is running. Restart it? (Y/N, default N)"
                                    if ($RestartConfirm -eq "Y" -or $RestartConfirm -eq "y") {
                                        Write-Host "Restarting service '$($Service.Name)' on server '$Server'..." -ForegroundColor Yellow
                                        Restart-Service -InputObject $Service
                                        Write-Host "Service restarted." -ForegroundColor Green
                                    }
                                }
                            }
                            catch {
                                Write-Host "Error updating service '$($Service.Name)' on server '$Server': $_" -ForegroundColor Red
                            }
                        }
                    }
                    else {
                        Write-Host "No services found using account '$ServiceAccount' on server '$Server'" -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "Error connecting to server '$Server': $_" -ForegroundColor Red
                }
            }
        }
        
        return $NewPassword
    }
    catch {
        Write-Host "Error updating password for service account '$ServiceAccount': $_" -ForegroundColor Red
        return $null
    }
}

# Function to schedule automatic password rotation
function Schedule-PasswordRotation {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TaskName,
        
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory=$true)]
        [string]$ServiceAccount,
        
        [Parameter(Mandatory=$false)]
        [int]$IntervalDays = 90,
        
        [Parameter(Mandatory=$false)]
        [string]$RunAsUser,
        
        [Parameter(Mandatory=$false)]
        [string]$Password
    )

    try {
        # Create task action
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -ServiceAccount `"$ServiceAccount`""
        
        # Create trigger for initial run and recurring schedule
        $StartTime = (Get-Date).AddMinutes(5)
        $Trigger = New-ScheduledTaskTrigger -Once -At $StartTime -RepetitionInterval (New-TimeSpan -Days $IntervalDays)
        
        # Create principal (who the task runs as)
        if ([string]::IsNullOrEmpty($RunAsUser)) {
            # Run as SYSTEM if no user specified
            $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            
            # Register the task
            Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Description "Automatic password rotation for service account $ServiceAccount"
        }
        else {
            # Run as specified user
            if ([string]::IsNullOrEmpty($Password)) {
                # Prompt for password if not provided
                $SecurePassword = Read-Host "Enter password for $RunAsUser" -AsSecureString
                $Credential = New-Object System.Management.Automation.PSCredential($RunAsUser, $SecurePassword)
            }
            else {
                # Use provided password
                $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
                $Credential = New-Object System.Management.Automation.PSCredential($RunAsUser, $SecurePassword)
            }
            
            # Create principal with the specified user
            $Principal = New-ScheduledTaskPrincipal -UserId $RunAsUser -LogonType Password -RunLevel Highest
            
            # Register the task with credentials
            Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Description "Automatic password rotation for service account $ServiceAccount" -User $RunAsUser -Password ($Credential.GetNetworkCredential().Password)
        }
        
        Write-Host "Scheduled task '$TaskName' has been created successfully." -ForegroundColor Green
        Write-Host "Next run time: $StartTime, then every $IntervalDays days." -ForegroundColor Cyan
    }
    catch {
        Write-Host "Error creating scheduled task: $_" -ForegroundColor Red
        
        # Additional error details for troubleshooting
        if ($_.Exception.InnerException) {
            Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
        
        # Provide guidance based on common errors
        if ($_.Exception.Message -match "Access is denied") {
            Write-Host "Tip: Make sure you're running this script with administrative privileges." -ForegroundColor Yellow
        }
        elseif ($_.Exception.Message -match "already exists") {
            Write-Host "Tip: A task with the name '$TaskName' already exists. Use a different name or delete the existing task first." -ForegroundColor Yellow
        }
        elseif ($_.Exception.Message -match "credentials") {
            Write-Host "Tip: There might be an issue with the provided credentials. Verify the username and password." -ForegroundColor Yellow
        }
    }
}