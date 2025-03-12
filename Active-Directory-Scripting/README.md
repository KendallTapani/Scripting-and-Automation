# Active Directory Scripting

A comprehensive collection of PowerShell scripts for managing and automating Active Directory tasks in the kendalltapani.com domain. These scripts are designed to streamline administrative tasks and improve efficiency in AD environments.

## Directory Structure

### User Management
Scripts for managing user accounts:
User creation and deletion, Password management, Account status monitoring, Bulk user operations, OU management

[![User Management](https://img.shields.io/badge/📁_User_Management-FF4B4B?style=for-the-badge)](https://github.com/KendallTapani/Scripting-and-Automation/tree/main/Active-Directory-Scripting/User-Management)

### Group Policy Management
Tools for managing AD groups and policies:
Group membership management, Security group auditing, Distribution list automation, Policy deployment and reporting

[![Group Policy](https://img.shields.io/badge/📁_Group_Policy_Management-4169E1?style=for-the-badge)](https://github.com/KendallTapani/Scripting-and-Automation/tree/main/Active-Directory-Scripting/Group-Policy-Management)

### Security and Compliance
Scripts focused on maintaining AD security:
Account lockout monitoring, Permission auditing, Security group management, Compliance reporting

[![Security](https://img.shields.io/badge/📁_Security_&_Compliance-40B982?style=for-the-badge)](https://github.com/KendallTapani/Scripting-and-Automation/tree/main/Active-Directory-Scripting/Security-and-Compliance)

### Computer Management
Tools for managing computer accounts:
Hardware/software inventory, Stale account cleanup, OU organization, System health monitoring

[![Computer](https://img.shields.io/badge/📁_Computer_Management-9B59B6?style=for-the-badge)](https://github.com/KendallTapani/Scripting-and-Automation/tree/main/Active-Directory-Scripting/Computer-Management)

<br/>
<br/>
<br/>

## User Management Scripts

### User Onboarding
A script for streamlined user creation in Active Directory with the following features:
- Interactive menu system
- Dynamic OU selection
- Automatic username generation (first initial + last name)
- Standard group assignments
- Hardcoded initial password with forced change at first login
- 30-day onboarding history tracking

<div style="display: flex; align-items: flex-start;">
<img src="User-Management/User-Onboarding/image1.png" height="300" width="auto" alt="User Onboarding Main Menu"/> <img src="User-Management/User-Onboarding/image2.png" height="300" width="auto" alt="Successful User Creation"/>
</div>

### User Offboarding
Manages the secure deactivation of user accounts with features including:
- Account disablement
- Automated move to "Disabled Users" OU
- 30-day retention before deletion
- Scheduled cleanup of expired accounts
- Detailed logging of offboarding actions

<div style="display: flex; align-items: flex-start;">
<img src="User-Management/User-Offboarding/image1.png" height="300" width="auto" alt="User Offboarding Process"/> <img src="User-Management/User-Offboarding/image2.png" height="300" width="auto" alt="Account Movement"/> <img src="User-Management/User-Offboarding/image3.png" height="300" width="auto" alt="Cleanup Operation"/>
</div>

### Account Locking/Unlocking
Manages user account states with enhanced features:
- Account locking/unlocking
- Remote computer reboot capability
- Network connectivity validation
- Detailed error handling and diagnostics

<img src="User-Management/Locking-Unlocking-Accounts/image.png" height="300" width="auto" alt="Lock/Unlock Operation"/>

## License
This project is licensed under the MIT License - see the LICENSE file for details.

