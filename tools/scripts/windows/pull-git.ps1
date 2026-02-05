function Bootstrap {
param (
  # HACK: If this is false, then every variable will be set with `$Using:` syntax.
  [bool]$DoPropagate = $true
)

Write-Host "Running bootstrap script!"
Get-Job | Remove-Job -Force

$creds
if ($DoPropagate) { 
  Write-Host "This script will propagate.`n" 
  $creds = Get-Credential -Message "Please enter the credentials to be used for propagation"#Read credentials
  $username = $creds.username
  $password = $creds.GetNetworkCredential().password

  # Get current domain using logged-on user's credentials
  $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
  $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

  if ($domain.name -eq $null)
  {
   write-host "Authentication failed - please verify your username and password."
   exit #terminate the script.
  } else {
   write-host "Successfully authenticated with domain ${domain.name}"
  }
} else { 
    Write-Host "This script will not propagate.`n" 
}


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$zipUrl = "https://github.com/nuccdc/tools/archive/main.zip"
$zipFilePath = "C:\toolz.zip"
$extractPath = "C:\"
$branchName = "tools-main"
# This is where the tools actually get put
$toolsDir = "${extractPath}${branchName}"

# Sysinternals + other tools
$SysinternalsLink = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
$SysinternalsOutpath = "C:\sysinternals.zip"
$SysinternalsZipName = "SysinternalsSuite.zip"

# Propagation/bootstrapping
$BootstrapScript = "${PSScriptRoot}\pull-git.ps1"
$BoostrapURL = "https://gitlab.com/nuccdc/tools/-/raw/main/scripts/windows/pull-git.ps1?ref_type=heads"


######################################### Misc tools for making things faster #########################################
function Execute-Parallel {
  param (
    [Parameter(Mandatory, ValueFromRemainingArguments=$true)]
    $Commands
  )
 
  # Use a hashtable to store job information for easy lookup
  $jobs = @{}
  $jobNo = 1
  foreach ($Command in $Commands) {
    # Execute the script on the remote computer as a background job
    $job = Start-Job -ScriptBlock $Command
    $jobNo = $jobNo + 1
    # Store the job with the computer name as key
    $jobs["$jobNo"] = $job
  }

  # Wait for all jobs to complete
  Get-Job | Wait-Job | Out-Null

  # Retrieve and display the results of each job
  foreach ($Command in $jobs.Keys) {
    $job = $jobs[$Command]
    $result = Receive-Job -Job $job
    #Write-Host $result.Value
    # Cleanup the job
    Remove-Job -Job $job
  }
}

Function Check-Privileges {
    if(!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        Write-Host "Run this script as administrator."
        Exit
    }
}
########################################################################################################################
# Download + Extract our tools
Write-Host "Checking that we have elevated privileges..."
Check-Privileges

Write-Host "Downloading tools..."

# Annoying popup... restarts my domain controller
Write-Host ".`t`[√] Excluding Jake's malware in defender..."
Add-MpPreference -ExclusionPath "$toolsDir\scripts\unix\linpeas.sh"
Add-MpPreference -ExclusionPath "$toolsDir\scripts\unix\persistence\diamorphine\diamorphine.ko"

# Download both sysinternals and the tools at the same time (we cant extract sysinterals until later though.
# Note that variables must use the `$Using:<varname>` syntax because they act like remote variables here
Execute-Parallel `
  { $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Using:zipUrl -OutFile $Using:zipFilePath 
    Write-Host ".`t[√] Downloaded tools" 
  } `
  { $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Using:SysinternalsLink -OutFile $Using:SysinternalsOutpath 
    Write-Host ".`t[√] Downloaded sysinternals" 
  }
Write-Host -NoNewline "`r`t[_] Expanding tools archive"
Expand-Archive -Force -Path $zipFilePath -DestinationPath $extractPath
Write-Information "Cleaning up"
Remove-Item $zipFilePath
Write-Host "`r.`t[√] Expanded tools archive"

# Sysinternals
## Extract the sysinternals zip we store
Write-Host -NoNewline "`r.`t[_] Expanding Sysinternals..."

Move-Item -Path C:\*.zip -Destination "$toolsDir\$SysinternalsZipName" -Force
Expand-Archive -Force -Path $toolsDir\$SysinternalsZipName -DestinationPath "$toolsDir\sysinternals"
Remove-Item "$toolsDir\$SysinternalsZipName"

Write-Host "`r.`t[√] Expanded Sysinternals..."


## EULA Registry key Stuff
Write-Host ".`tAccepting Sysinternals EULA"
Invoke-Command {reg.exe ADD HKCU\Software\Sysinternals /v EulaAccepted /t REG_DWORD /d 1 /f} | Out-Null
Invoke-Command {reg.exe ADD HKU\.DEFAULT\Software\Sysinternals /v EulaAccepted /t REG_DWORD /d 1 /f} | Out-Null
Write-Host ".`t`t[√] EULA Accepted"

Write-Host "[√] Tools downloaded and extracted.`n"

Write-Host "Opening explorer in $toolsDir"
Invoke-Item "$toolsDir"

#######################
# Misc other tasks we need not forget

## Registry backups

# NOTE: double backups (without force overwrite) will hog system resources indefinitely
# use `Get-Job | Remove-Job -Force` to kill the jobs

Write-Host "`nPerforming registry backups..."
Execute-Parallel `
  { reg export HKLM $Using:toolsDir\HKLM.reg /y 
    Write-Host ".`t[√] Backed up HKLM" 
  } `
  { reg export HKCR $Using:toolsDir\HKCR.reg /y 
    Write-Host ".`t[√] Backed up HKCR" 
  } `
  { reg export HKCU $Using:toolsDir\HKCU.reg /y 
    Write-Host ".`t[√] Backed up HKCU" 
  } `
  { reg export HKCC $Using:toolsDir\HKCC.reg /y 
    Write-Host ".`t[√] Backed up HKCC" 
  } `
  { reg export HKU $Using:toolsDir\HKU.reg /y 
    Write-Host ".`t[√] Backed up HKU" 
  }
Write-Host "[√] Registry backups complete"
Write-Host "Registry backups can be found in the $toolsDir`n"


## Make the tools directory only readable by admins
Write-Host "Applying self-protection logic, making tools only readable by admins..."
$ToolsAcl = Get-Acl -Path "$toolsDir"
$isProtected = $true
$preserveInheritance = $true
$ToolsAcl.SetAccessRuleProtection($isProtected, $preserveInheritance)
Get-ChildItem -Path "$toolsDir" -Recurse -Include "*" -Force | Set-Acl -AclObject $ToolsAcl
Write-Host "[√] Self-protection logic applied"


Write-Host "[√] All script actions performed. Local Tools Bootstrap Complete."

####################################### PROPAGATION LOGIC ###########################################

# We have the adprop stuff locally, so let's just call those scripts... Also, we don't want to
# propagate indefinitely, so check if we are set to propagate

if ($DoPropagate) {
  Write-Host "`nPerforming AD Propagation"
  
  ########################## GPO STUFF #####################################################
  Write-Host -NoNewline ".`t[_] Setting GPOs for WinRM"
  Import-Module GroupPolicy

  $Reg = 
@"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service]
"DisableRunAs"=dword:00000001
"HttpCompatibilityListener"=dword:00000000
"AllowBasic"=dword:00000000
"AllowAutoConfig"=dword:00000001
"IPv4Filter"=""
"IPv6Filter"=""
"@

  echo $Reg | Out-File -FilePath "$toolsDir\winrm.reg"

  reg import "$toolsDir\winrm.reg" | Out-Null

  Write-Host "`r.`t[√] Set GPO for WinRM"
  Write-Host -NoNewline ".`t[_] Pushing GPOs..."
  Invoke-GPUpdate | Out-Null
  Write-Host "`r.`t[√] Pushed GPOs Successfully!"

  ########################### MACHINE ENUMERATION ###########################################
  
  # Enumerate other machines (excluding this one)
  $OtherComputers = Get-ADComputer -Filter * | Where-Object {$_.name -notmatch $env:computername}
  Write-Host ".`tFound machines:"
  $OtherComputers | Select-Object -ExpandProperty Name | Out-String -Stream | ForEach-Object { Write-Host ".`t`t$_"}

  
  # Use a hashtable to store job information for easy lookup
  $jobs = @{}

  foreach ($computer in $OtherComputers) {
    Write-Host ".`tRunning job on ${computer.Name} with script $BootstrapScript"
    #$job = Invoke-Command -ComputerName $computer.Name -FilePath $BootstrapScript -AsJob -ArgumentList $False -Credential $creds
    $job = Invoke-Command -ComputerName $computer.Name -AsJob -ArgumentList $False -Credential $creds -ScriptBlock {
      $ProgressPreference = 'SilentlyContinue'
      Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nuccdc/tools/main/scripts/windows/pull-git.ps1" -OutFile "C:\bootstrap.ps1"
      start-process "powershell.exe" -argumentlist '-File',"C:\bootstrap.ps1", '-DoPropagate', $false
    }
    $jobs[$computer.Name] = $job
  }
  # Wait for all jobs to complete
  Get-Job | Wait-Job -Timeout 40

  # Retrieve and display the results of each job
  foreach ($computerName in $jobs.Keys) {
    $job = $jobs[$computerName]
    $result = Receive-Job -Job $job
    Write-Host "Results for ${computerName}:"
    Write-Host $result
    Write-Host "-----------------------------------"
    # Cleanup the job
    Remove-Job -Job $job
  }
} else {
  Write-Host "Skipping propagation."
}


}

$Status = (Get-Host).Name

if ($Status -like "ServerRemoteHost") {
  Bootstrap $false
} else {
  Bootstrap
}
 