# Active Directory Management Scripts

A comprehensive collection of PowerShell scripts for managing Active Directory environments.

## Navigation

[![User Management](https://img.shields.io/badge/User%20Management-View%20Scripts-blue?style=for-the-badge)](User-Management/)
[![Group Policy](https://img.shields.io/badge/Group%20Policy-View%20Scripts-green?style=for-the-badge)](Group-Policy/)
[![Computer Management](https://img.shields.io/badge/Computer%20Management-View%20Scripts-orange?style=for-the-badge)](Computer-Management/)

## Sections Overview

### User Management
<div style="display: flex; align-items: flex-start;">
<img src="User-Management/User-Onboarding/image1.png" height="300" width="auto" alt="User Onboarding"/> <img src="User-Management/User-Onboarding/image2.png" height="300" width="auto" alt="User Creation"/>
</div>
- **Account Creation**: Automates the process of creating new user accounts with standardized attributes
- **Account Termination**: Handles the secure deactivation and cleanup of user accounts
- **Password Management**: Tools for password resets, expiration management, and complexity verification
- **Bulk Operations**: Scripts for performing actions on multiple user accounts simultaneously
- **Reporting**: Generate detailed reports on user account status, permissions, and activities

### Group Policy Management
<div style="display: flex; align-items: flex-start;">
<img src="Group-Policy/Group-Policy-Management/image1.png" height="300" width="auto" alt="GPO Management"/> <img src="Group-Policy/Group-Policy-Management/image2.png" height="300" width="auto" alt="GPO Settings"/>
</div>
- **GPO Creation**: Templates and scripts for creating standardized Group Policy Objects
- **Policy Deployment**: Automate the process of linking and applying GPOs to OUs
- **Backup and Restore**: Tools for backing up and restoring Group Policy configurations
- **Health Checks**: Scripts to verify GPO settings and identify potential issues
- **Documentation**: Generate comprehensive reports of GPO settings and assignments

### Computer Management
<div style="display: flex; align-items: flex-start;">
<img src="Computer-Management/Hardware-Software-Inventory-Report/image.png" height="300" width="auto" alt="Hardware Inventory"/> <img src="Computer-Management/Computer-Account-Management/image.png" height="300" width="auto" alt="Account Management"/> <img src="Computer-Management/Computer-Inventory-Report/image.png" height="300" width="auto" alt="Inventory Report"/>
</div>
- **Hardware Inventory**: Collect detailed hardware specifications from domain computers
- **Software Inventory**: Track installed software, versions, and installation dates
- **Account Management**: Tools for managing computer accounts in Active Directory
- **Health Monitoring**: Scripts to check computer status and identify issues
- **Reporting**: Generate comprehensive inventory and status reports

## Requirements

- Windows PowerShell 5.1 or later
- Active Directory PowerShell module
- Domain Administrator or appropriate delegated rights
- Remote Server Administration Tools (RSAT)

## Installation

1. Clone the repository:
```powershell
git clone https://github.com/yourusername/Active-Directory-Scripting.git
```

2. Navigate to the script directory:
```powershell
cd Active-Directory-Scripting
```

3. Run desired scripts with administrative privileges

## Usage

Each section contains its own README with specific usage instructions. Navigate to the desired section using the badges above.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

