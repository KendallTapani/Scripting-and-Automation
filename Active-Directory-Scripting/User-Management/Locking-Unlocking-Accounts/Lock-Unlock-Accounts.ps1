# Lock/Unlock Accounts Script for kendalltapani.com
$domain = "kendalltapani.com"
$user = Read-Host "Enter username to manage"
$action = Read-Host "Enter action (lock/unlock)"

if ($action -eq "lock") {
    try {
        # First disable the account
        Disable-ADAccount -Identity $user
        Write-Host "Locked account: $user"

        # Ask for target computer
        $targetComputer = Read-Host "Enter computer name where user is logged in (press Enter to skip)"
        
        if ($targetComputer) {
            Write-Host "`nTrying to connect to $targetComputer..."
            
            try {
                # Try to resolve the computer name first
                $resolved = Resolve-DnsName -Name $targetComputer -ErrorAction Stop
                Write-Host "DNS Resolution successful. IP: $($resolved.IPAddress)"
                
                $confirm = Read-Host "Are you sure you want to reboot $targetComputer? (yes/no)"
                if ($confirm -eq "yes") {
                    Write-Host "Attempting to manage remote computer..."
                    
                    # Try to disable firewall first
                    Write-Host "Attempting to temporarily disable firewall..."
                    $session = $null
                    try {
                        $session = New-PSSession -ComputerName $targetComputer
                        Invoke-Command -Session $session -ScriptBlock {
                            # Store original firewall states
                            $originalStates = Get-NetFirewallProfile | Select-Object Name, Enabled
                            
                            # Disable all firewall profiles temporarily
                            Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
                            Write-Host "Firewall disabled successfully"
                            
                            # Force restart
                            Write-Host "Initiating restart..."
                            
                            # Re-enable firewall profiles before restarting
                            foreach ($profile in $originalStates) {
                                Set-NetFirewallProfile -Profile $profile.Name -Enabled $profile.Enabled
                            }
                            Write-Host "Firewall restored to original state"
                            
                            # Now restart
                            Restart-Computer -Force
                        }
                        Write-Host "Reboot command sent successfully"
                    }
                    catch {
                        Write-Host "Failed to connect using PowerShell remoting. Trying direct restart..."
                        try {
                            # Try to create a temporary session just to restore firewall if it was disabled
                            if ($session) {
                                Invoke-Command -Session $session -ScriptBlock {
                                    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
                                    Write-Host "Firewall re-enabled for safety"
                                }
                            }
                            
                            Stop-Computer -ComputerName $targetComputer -Force
                            Write-Host "Shutdown command sent using Stop-Computer"
                        }
                        catch {
                            Write-Host "All reboot attempts failed. Error: $_"
                            Write-Host "You may need to manually restart the computer"
                        }
                    }
                    finally {
                        # Clean up session if it exists
                        if ($session) {
                            Remove-PSSession $session
                        }
                    }
                } else {
                    Write-Host "Reboot cancelled"
                }
            } catch {
                Write-Host "Error: $_"
                Write-Host "Failed to reboot computer. Please check:"
                Write-Host "1. Computer name is correct: $targetComputer"
                Write-Host "2. Network connectivity (IP: $($resolved.IPAddress))"
                Write-Host "3. Administrative rights on target computer"
                Write-Host "4. Windows Firewall settings"
            }
        }
    } catch {
        Write-Host "Error: $_"
    }
} elseif ($action -eq "unlock") {
    Enable-ADAccount -Identity $user
    Write-Host "Unlocked account: $user"
} else {
    Write-Host "Invalid action. Please use 'lock' or 'unlock'"
} 