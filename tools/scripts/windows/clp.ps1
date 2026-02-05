# change local passwordz
$localUsers = get-localuser | Where-Object { $_.Name -ne "name" } | Select-Object -Property Name
$names = foreach ($user in $localUsers) {
    $user.Name
}
Write-Host "Usernames:"
$names -join " "
$selectedUsers = Read-Host "Enter comma-separated list of LOCAL users to change password"
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
    $UserAccount = Get-LocalUser -Name $user
    $UserAccount | Set-LocalUser -Password $password1
}