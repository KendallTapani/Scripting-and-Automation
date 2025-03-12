# Computer Management Scripts

This section contains PowerShell scripts for managing computer accounts in Active Directory, including hardware inventory, software inventory, and computer account management.

## Scripts Overview

### Hardware and Software Inventory Report
![Hardware-Software-Inventory](Hardware-Software-Inventory-Report/image.png)
- **Purpose**: Generates detailed reports of hardware and software inventory for domain computers
- **Features**:
  - Collects hardware information (CPU, Memory, Disk Space, Network Adapters)
  - Gathers installed software details (Name, Version, Vendor, Install Date)
  - Supports single computer or all domain computers scanning
  - Generates HTML reports with formatted tables
  - Uses CIM/WMI for reliable data collection
  - Includes error handling and connectivity checks

### Computer Account Management
![Computer-Account-Management](Computer-Account-Management/image.png)
- **Purpose**: Manages computer accounts in Active Directory
- **Features**:
  - Move computers between OUs
  - Disable/Enable computer accounts
  - Delete stale computer accounts
  - Search and filter computer accounts
  - Bulk operations support
  - Automated OU creation if needed

### Computer Inventory Report
![Computer-Inventory](Computer-Inventory-Report/image.png)
- **Purpose**: Generates comprehensive inventory reports of computer accounts
- **Features**:
  - Lists all computer accounts in the domain
  - Shows last logon time and account status
  - Identifies stale accounts
  - Exports to CSV for easy analysis
  - Includes OU location information
  - Supports custom filtering options

## Usage Instructions

1. **Hardware and Software Inventory Report**:
   ```powershell
   # Run as administrator
   .\Hardware-Software-Inventory-Report\Hardware-Software-Inventory.ps1
   ```
   - Select option 1 for single computer or 2 for all domain computers
   - Reports are saved in C:\Reports directory

2. **Computer Account Management**:
   ```powershell
   # Run as administrator
   .\Computer-Account-Management\Manage-ComputerAccounts.ps1
   ```
   - Follow the interactive menu for various management options
   - Supports bulk operations through CSV import

3. **Computer Inventory Report**:
   ```powershell
   # Run as administrator
   .\Computer-Inventory-Report\Computer-Inventory.ps1
   ```
   - Reports are generated in CSV format
   - Use filters to focus on specific criteria

## Requirements

- Windows PowerShell 5.1 or later
- Active Directory PowerShell module
- Domain Administrator or appropriate delegated rights
- Remote Server Administration Tools (RSAT)
- WinRM enabled for remote management

## Security Considerations

- Run all scripts with appropriate administrative privileges
- Review and test in a non-production environment first
- Follow the principle of least privilege when delegating access
- Monitor and audit script execution through PowerShell logging

## Error Handling

All scripts include comprehensive error handling for common scenarios:
- Network connectivity issues
- Permission problems
- Resource availability
- Invalid input validation

## Logging

Operations are logged with appropriate verbosity:
- Success/failure status
- Error messages with details
- Operation timestamps
- Affected objects 