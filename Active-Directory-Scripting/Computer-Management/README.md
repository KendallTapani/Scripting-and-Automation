# Computer Management Scripts

A collection of PowerShell scripts for managing Active Directory computer accounts in the kendalltapani.com domain. These scripts provide automated solutions for computer inventory, organization, and maintenance tasks.

## Available Scripts

### Hardware and Software Inventory
A comprehensive inventory tool with the following features:
- Detailed hardware information collection
- Software inventory with version tracking
- HTML report generation
- Single computer or domain-wide scanning
- Network connectivity validation
- Automatic report organization

<div style="display: flex; align-items: flex-start;">
<img src="Hardware-Software-Inventory-Report/image1.png" height="300" width="auto" alt="Inventory Tool Menu"/>
<img src="Hardware-Software-Inventory-Report/image2.png" height="300" width="auto" alt="Generated Report"/>
</div>

### Computer Account Organization
Manages computer account placement in Active Directory:
- Dynamic OU structure creation
- Automatic computer categorization
- Bulk computer moves
- Location-based organization
- Detailed move logging

<div style="display: flex; align-items: flex-start;">
<img src="Computer-OU-Organization/image1.png" height="300" width="auto" alt="Organization Tool"/>
<img src="Computer-OU-Organization/image2.png" height="300" width="auto" alt="OU Structure"/>
<img src="Computer-OU-Organization/image3.png" height="300" width="auto" alt="Move Operation"/>
</div>

### Stale Computer Cleanup
Identifies and manages inactive computer accounts:
- Automated stale account detection
- Configurable inactivity thresholds
- Scheduled cleanup operations
- Backup of removed accounts
- Detailed cleanup reporting

<img src="Stale-Computer-Cleanup/image.png" height="300" width="auto" alt="Cleanup Operation"/>

## Requirements
- PowerShell 5.1 or higher
- Active Directory PowerShell module
- Administrative permissions in your AD environment
- Windows Remote Management (WinRM) enabled for remote operations
- RSAT Tools installed for AD management 