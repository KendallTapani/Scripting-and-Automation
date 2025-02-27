#Create users with CSV
$demoPath = 'C:\Users\a-ktapani\Documents\GitHub\Scripting-and-Automation\AD-Scripting'
$employees = Import-Csv "$demoPath\Accounts.csv"

$commonUserPassword = "Password1"

## Do some stuff for each employee in the CSV file
foreach ($employee in $employees)
{
    #region Figure out the username to assign
    $firstInitial = $employee.FirstName.SubString(0,1)
    $username = "$firstInitial$($employee.LastName)"
    Write-Verbose -Message "Checking username [$($username)]..."
    if (Get-ADUser -Filter "samAccountName -eq '$username'") {
        Write-Warning "Username [$($username)] is taken."
        ## Checking the second username
        $userName = '{0}{1}{2}' -f $firstInitial,$employee.MiddleInitial,$employee.LastName
        Write-Verbose -Message "Checking username [$($username)]..."
        if (Get-ADUser -Filter "samAccountName -eq '$username'") {
            throw "The username [$($username)] is already taken. Unable to create user."
        }
    }
    #endregion

    #region Create the user ensuring it's in the right OU
    $NewUserParams = @{
        'Title' = $employee.Title
        'UserPrincipalName' = $Username
        'Name' = $Username
        'Path' = "OU=$($employee.Department),DC=kendalltapani,DC=com"
        'GivenName' = $employee.FirstName
        'Surname' = $employee.LastName
        'SamAccountName' = $Username
        'DisplayName' = "$($employee.FirstName) $($employee.LastName)"
        'Department' = $employee.Department
        'AccountPassword' = (ConvertTo-SecureString $commonUserPassword -AsPlainText -Force)
        'Enabled' = $true
        'Initials' = $employee.MiddleInitial
        'ChangePasswordAtLogon' = $true
    }
    Write-Verbose -Message "Creating user [$($username)]..."
    New-ADUser @NewUserParams
    Write-Verbose -Message 'DONE'
    #endregion 
    
    
    ##Add the user to the All users group
    Write-Verbose -Message "Adding user to All Users group..."
    Add-ADGroupMember -Identity 'All Users' -Members $Username
    Write-Verbose -Message 'DONE'
}