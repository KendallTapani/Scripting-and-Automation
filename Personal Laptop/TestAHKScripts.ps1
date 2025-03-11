# Simple script to test running AHK files directly
Write-Host "Starting AHK Test Script..."

# Path to AutoHotkey executable and scripts
$ahkPath = "C:\Users\kenda\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$scriptPath = "C:\Scripts\AHK"

# Verify AutoHotkey exists
if (-not (Test-Path -Path $ahkPath)) {
    Write-Host "ERROR: AutoHotkey not found at: $ahkPath"
    exit 1
}

# Get all AHK files
$ahkFiles = Get-ChildItem -Path $scriptPath -Filter "*.ahk" -File

if ($ahkFiles.Count -eq 0) {
    Write-Host "No AHK files found in $scriptPath"
    exit 1
}

Write-Host "Found $($ahkFiles.Count) AHK files"

# Run each AHK file
foreach ($file in $ahkFiles) {
    Write-Host "Running: $($file.Name)"
    try {
        Start-Process -FilePath $ahkPath -ArgumentList "`"$($file.FullName)`"" -NoNewWindow
        Write-Host "Started $($file.Name) successfully"
    }
    catch {
        Write-Host "Error running $($file.Name): $($_.Exception.Message)"
    }
}

Write-Host "All scripts started. Check that they are running in Task Manager." 