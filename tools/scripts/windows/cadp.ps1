# change active directory passwords
$adUsers = Get-ADUser -Filter *
$names = $adUsers | Select-Object -Property SamAccountName

$names = foreach ($user in $adUsers) {
    $user.samaccountname
}

Write-Host "Usernames:"
$names -join " "

$selectedUsers = Read-Host "Enter comma-separated list of AD users to change password"
do {
    $password1 = Read-Host "Enter password" -AsSecureString
    $password2 = Read-Host "Re-enter password" -AsSecureString
    $password1_text = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1))
    $password2_text = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2))
    if ($password1_text -ne $password2_text) {
        Write-Host "Passwords do not match. Please try again."
    }
} until ($password1_text -eq $password2_text)
foreach ($user in $selectedUsers.Split(' ')) {
    Set-ADAccountPassword -Identity $user -NewPassword $password1 -Reset
}