# Active Directory Scripting and Automation

This repository contains a comprehensive collection of PowerShell scripts for managing and automating various Active Directory tasks. The scripts are organized into different categories based on their functionality.

## Table of Contents
- [User Management](#user-management)
- [Group Policy Management](#group-policy-management)
- [Security and Compliance](#security-and-compliance)
- [Computer Management](#computer-management)

## User Management

### Basic User Operations
- **Password Resetting**: Scripts for basic password reset operations
- **User Onboarding**: Automated process for creating new user accounts with standardized settings
- **User Offboarding**: Scripts to handle employee departures, including account deactivation and cleanup
- **Bulk User Creation**: Tools for creating multiple user accounts simultaneously
- **Account Locking/Unlocking**: Scripts to manage account lock status
- **OU Management**: Tools for moving users between Organizational Units
- **Helpdesk AD Management**: Comprehensive tools for helpdesk staff to manage common AD tasks
- **Scheduled Password Reset**: Automated password reset scheduling system
- **Inactive User Management**: Scripts to identify and handle dormant user accounts

## Group Policy Management

### Group Management Tools
- **Group Auditing**: Scripts for auditing group memberships and permissions
- **Security Group Reporting**: Detailed reporting tools for security group permissions
- **Distribution List Management**: Tools for managing email distribution lists
- **Dynamic Group Membership**: Scripts for automating group membership based on rules

## Security and Compliance

### Security Tools
- **Account Lockout Monitoring**: Tools to track and manage account lockouts
- **Privileged Account Management**: Comprehensive management of high-privilege accounts
- **Permission Auditing**: Scripts for auditing and reporting on AD permissions
- **Security Group Management**: Tools for managing security group memberships and access controls

## Computer Management

### Computer Account Tools
- **Hardware/Software Inventory**: Scripts for gathering and reporting on computer inventory
- **Stale Account Management**: Tools to identify and manage inactive computer accounts
- **OU Organization**: Scripts for organizing computer accounts in appropriate OUs

## Usage

Each script directory contains its own README with specific usage instructions and requirements. Generally, these scripts require:

1. PowerShell 5.1 or higher
2. Active Directory PowerShell module
3. Appropriate administrative permissions in your AD environment

## Best Practices

- Always test scripts in a non-production environment first
- Review and modify variables according to your environment
- Maintain proper documentation of any customizations
- Follow the principle of least privilege when executing scripts




## Personal Device Scripting
Here is a list of scripts on my personal computer:
<br/>
#### 1. Ram clear: 
When I need to run a bunch of VMs on my laptop, I use a shortcut to clear all noncritical processes and services, usually freeing up a couple extra GBs of ram.
Also works for better gaming performance.


#### 2. Job Searching Automation
My fingers were getting tired typing my info into job search websites, so I made a couple Powershell and ahk scripts to save time. Scripts do the following:
<br/>
Opens all the relevant job sites I use to apply; binds my personal info to hotkeys, pulling from a txt file ; Opens a new email, pastes a subject and message template
