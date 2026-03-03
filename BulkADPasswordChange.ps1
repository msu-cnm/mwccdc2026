[cmdletbinding()]
Param (
  [Parameter(Mandatory=$false,Position=0)][string]$Password,
  [Parameter(Mandatory=$false)][switch]$ChangePasswordAtLogon = $false
)

$ErrorActionPreference = "Stop"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
  Write-Warning "Not running elevated. Open PowerShell as administrator and run script again."
  Exit
}


$DateSuffix = "{0:yyyy-MM-dd}-{1}" -f (Get-Date), (Get-Date).Ticks

function GeneratePassword {

param (

[int]$length = 20

)

$capletters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

$letters = "abcdefghijklmnopqrstuvwxyz"

$numbers = "0123456789"

$symbols = "!@#$%^&*()-_=+~`[]{};:/|.,<>"

$password = ""


if ($length -gt 1000) {

return "Error! length is too long."

}


elseif ($length -lt 1) {

return "Error! length is too short."

}


for ($i = 0; $i -lt $length; $i++) {


$randomarr = Get-Random (1..4)


switch ($randomarr) {

1 { $randomchar = Get-Random (0..($capletters.Length - 1)) ; $password += $capletters[$randomchar] ; break}

2 { $randomchar = Get-Random (0..($letters.Length - 1)) ; $password += $letters[$randomchar] ; break}

3 { $randomchar = Get-Random (0..($numbers.Length - 1)) ; $password += $numbers[$randomchar] ; break}

4 { $randomchar = Get-Random (0..($symbols.Length - 1)) ; $password += $symbols[$randomchar] ; break}

}


}


return $password


}
$PasswordChangeGroup = "PasswordChange-$DateSuffix"
New-ADGroup -GroupCategory Security -GroupScope Global -Description "Temporary security group created by $($MyInvocation.MyCommand.Name)." $PasswordChangeGroup

Write-Host -NoNewline "Temporary password change group created. Press Enter to open ADUC and add users and/or groups to `"${PasswordChangeGroup}`"."
Read-Host

Start-Process "mmc.exe" "dsa.msc"

Write-Host -NoNewline "Press Enter when all required members have been added to group."
Read-Host

$PasswordChangeUsers = Get-ADGroupMember $PasswordChangeGroup -Recursive | Get-ADUser -Properties *
$Results = @()
$PasswordChangeUsers | % {
  if ($Password) {
    $NewPassword = $Password
  } else {
    $NewPassword = GeneratePassword
  }
  $Results += [PSCustomObject]@{
    "Name"               = $_.DisplayName
    "Username"           = $_.SamAccountName
    "Email"              = $_.EmailAddress
    "MobilePhone"        = $_.MobilePhone
    "Phone"              = $_.telephoneNumber
    "Office"             = $_.physicalDeliveryOfficeName
    "SID"                = ($_.SID).Value
    "Password"           = $NewPassword
  }
}

$Results | Format-Table Name, Username, Password -AutoSize
Write-Host -NoNewline "The above password changes will be made. Results will be exported to a CSV file. Continue? [N/y] "
if ((Read-Host).ToLower() -eq "y") {
  $CSVFile = Join-Path $PSScriptRoot "PasswordChange-$DateSuffix.csv"
  $Results | select Name, Username, Password, Email, MobilePhone, Phone, Office | Export-Csv -NoTypeInformation $CSVFile
  Write-Host "Results saved to `"${CSVFile}`"."

  $Results | % {
    Set-ADAccountPassword $_.SID -NewPassword (ConvertTo-SecureString -AsPlainText $_.Password -Force)
    if ($ChangePasswordAtLogon) {
      Set-ADUser $_.SID -ChangePasswordAtLogon:$true
    }
  }

  Write-Host "Done."
} else {
  Write-Host "Aborted."
}

Remove-ADGroup $PasswordChangeGroup -Confirm:$false