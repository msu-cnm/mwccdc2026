# Change User Passwords Except for Selected Users

This PowerShell script changes the passwords for all users except the ones specified in the excluded list.

## Script

```powershell
# List of users to exclude
$excludedUsers = @("Administrator", "ServiceAccount")

# New password for the users
$newPassword = "NewPassword123!"

# Get all users except excluded ones
Get-LocalUser | ForEach-Object {
    if ($excludedUsers -notcontains $_.Name) {
        # Change user password
        $_ | Set-LocalUser -Password (ConvertTo-SecureString $newPassword -AsPlainText -Force)
        Write-Output "Changed password for $($_.Name)"
    }
}
