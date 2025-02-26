#======================================================================================
# Function: Open-JobPortals
# Purpose: Opens all job portal websites defined in job_portals.txt in new window
#======================================================================================

function Open-JobPortals {
    [CmdletBinding()]
    param()

    try {
        # Read job portal URLs from config file
        $portalUrls = Get-Content -Path "C:\Scripts\Job\Config\job_portals.txt" -ErrorAction Stop

        # Remove any empty lines
        $portalUrls = $portalUrls | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        if ($portalUrls.Count -gt 0) {
            # Open first URL in new window, rest will be tabs
            Start-Process firefox -ArgumentList "-new-window", $portalUrls[0]
            
            # Short sleep to ensure window is created
            Start-Sleep -Milliseconds 500

            # Open rest of URLs in new tabs in that window
            $portalUrls | Select-Object -Skip 1 | ForEach-Object {
                Start-Process firefox -ArgumentList "-new-tab", $_
            }
        }
    }
    catch {
        Write-Error "Failed to open job portals: $_"
    }
}

#======================================================================================
# Function: Get-ApplicationInfo
# Purpose: Opens personal information file in notepad for reference
#======================================================================================

function Get-ApplicationInfo {
    [CmdletBinding()]
    param()

    try {
        # Simply open the file in notepad for reference
        Start-Process notepad.exe -ArgumentList "C:\Scripts\Job\Config\resume_info.txt"
    }
    catch {
        Write-Error "Failed to open application info: $_"
    }
}

# Export functions
Export-ModuleMember -Function Open-JobPortals, Get-ApplicationInfo