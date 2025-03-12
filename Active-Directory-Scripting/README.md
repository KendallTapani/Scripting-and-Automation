# Active Directory Scripting

A comprehensive collection of PowerShell scripts for managing and automating Active Directory tasks in the kendalltapani.com domain. These scripts are designed to streamline administrative tasks and improve efficiency in AD environments.

## Directory Structure

### User Management
Scripts for managing user accounts

### Group Policy Management
Tools for managing AD groups and policies

### Security and Compliance
Scripts focused on maintaining AD security

### Computer Management
Tools for managing computer accounts




<br/>
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
<img src="User-Management/User-Onboarding/image1.png" width="200" alt="User Onboarding Main Menu"/> <img src="User-Management/User-Onboarding/image2.png" width="200" alt="Successful User Creation"/>
</div>

### User Offboarding
Manages the secure deactivation of user accounts with features including:
- Account disablement
- Automated move to "Disabled Users" OU
- 30-day retention before deletion
- Scheduled cleanup of expired accounts
- Detailed logging of offboarding actions

<div style="display: flex; align-items: flex-start;">
<img src="User-Management/User-Offboarding/image1.png" width="200" alt="User Offboarding Process"/> <img src="User-Management/User-Offboarding/image2.png" width="200" alt="Account Movement"/> <img src="User-Management/User-Offboarding/image3.png" width="200" alt="Cleanup Operation"/>
</div>

### Account Locking/Unlocking
Manages user account states with enhanced features:
- Account locking/unlocking
- Remote computer reboot capability
- Network connectivity validation
- Detailed error handling and diagnostics

<img src="User-Management/Locking-Unlocking-Accounts/image.png" width="250" alt="Lock/Unlock Operation"/>

## License
This project is licensed under the MIT License - see the LICENSE file for details.

