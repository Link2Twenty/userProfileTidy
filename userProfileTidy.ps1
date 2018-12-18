<#
Powershell script to delete idle roaming profiles from a windows computer

Usage: userProfileTidy.ps1 [OPTION...]
-a, -age          Set minimum age of profiles, in days (required)
-d, -debug        Output process to console for debugging
-f, -force        Force culling, will remove local accounts with mismatched domain
-dryrun           Run through process but do not commit any changes, debug implied
-?, -h, -help     Display help screen

userProfileTidy.ps1 --age 28

@author Andrew Bone <https://github.com/link2twenty>
@licence MIT
@version 0.0.8
#>

#Requires -RunAsAdministrator

# Default value for age
# Roaming accounts over this age will be removed
$age = 30;
$forceMode = 0;
# Manually enter users you want to be safe from removal
$safeProfiles = @( );

# Check for -debug or -dryrun
$dryrun = $args.contains('-dryrun') -or $args.contains('--dryrun');
$debug = $args.contains('-d') -or $args.contains('-debug') -or $args.contains('--debug') -or $dryrun;

# Will output to screen if in debug mode
function Write-Log($head = "debug", $color = "yellow", $msg) {
  if ($debug) {
    Write-Host "${head}: " -foreground $color -nonewline;
    Write-host $msg -foreground white;
  }
}

# Outputs help information to screen then quits
function Show-Help() {
  Write-Host "Usage: userProfileTidy.ps1 [OPTION...]";
  Write-Host "-a, -age          Set minimum age of profiles, in days (required)";
  Write-Host "-d, -debug        Output process to console for debugging";
  Write-Host "-dryrun           Run through process but do not commit any changes, debug implied";
  Write-Host "-f, -force        Force culling, will remove local accounts with mismatched domain";
  Write-Host "-?, -h, -help     Display help screen";
  exit 0;
}

# Sets $age depending on arguemets
function Set-Age($age) {
  if (!($age -is [int])) {
    Write-Log -head "error" -color "red" -msg "age must be numeric";
    exit 1;
  }
  $script:age = $age;
}

function Set-Force() {
  $script:forceMode = 1;
}

# Check all arguments and do appropriate actions
for ($i = 0; $i -lt $args.Length; $i++) {
  switch ($args[$i]) {
    "-a"      {Set-Age -age $args[$i + 1]};
    "-age"    {Set-Age -age $args[$i + 1]};
    "--age"   {Set-Age -age $args[$i + 1]};
    "-f"      {Set-Force};
    "-force"  {Set-Force};
    "--force" {Set-Force};
    "-?"      {Show-Help};
    "-h"      {Show-Help};
    "-help"   {Show-Help};
    "--help"  {Show-Help};
  }
}

# Todays date
$today = Get-Date;
Write-Log -msg "Set date $today";

# Get a list of all user profiles
$users = Get-WmiObject Win32_UserProfile;
Write-Log -msg "Discovered $($users.length) users";

# For each user in list
Foreach ($user in $users) {
  # Normalize profile name.
  $userPath = (Split-Path $user.LocalPath -Leaf).ToLower();
  Write-log -msg "Checking user $userPath";
  $script:domainMismatch = 0;
  if($forceMode) {
    $error.clear();
    Get-LocalUser -Name $userPath -erroraction 'silentlycontinue' | out-null;
    if($error) {
      $script:domainMismatch = 1;
    }
  };
  # Skip `special` users
  if ($safeProfiles.contains($userPath) -or $user.Special) {
    Write-log -color "magenta" -msg "User $userPath is special, skipping..."; 
    continue;
  };
  # If account is not Roaming skip
  if ((!$user.RoamingConfigured) -and $domainMismatch -eq 0) {
    Write-log -color "magenta" -msg "User $userPath is local, skipping..."; 
    continue;
  };
  # If user is logged in skip
  if ( query user $userPath 2>$null) {
    Write-log -color "magenta" -msg "User $userPath is currently logged in, skipping..."; 
    continue;
  };
  Write-log -head "start" -color "green" -msg "User $userPath has a roaming profile";
  # Calculate LoginAge based on LastLogin 

  if (Test-Path $user.localPath) {
    $script:userLastLogin = (Get-Item $user.localPath).LastWriteTime;
    Write-log -msg "Getting localPath LastWriteTime: $script:userLastLogin";
  } elseif($user.LastUseTime) {
    $script:userLastLogin = $user.ConvertToDateTime($user.LastUseTime);
    Write-log -msg "Getting LastUseTime: $script:userLastLogin";
  } elseif($user.LastDownloadTime) {
    $script:userLastLogin = $user.ConvertToDateTime($user.LastDownloadTime);
    Write-log -msg "Getting LastDownloadTime: $script:userLastLogin";
  } elseif($user.LastuploadTime) {
    $script:userLastLogin = $user.ConvertToDateTime($user.LastuploadTime);
    Write-log -msg "Getting LastuploadTime: $script:userLastLogin";
  } else {
    $script:userLastLogin = $user.ConvertToDateTime("19700101000000.000000+000");
  }

  # Skip if date is not found
  if ( !$script:userLastLogin ) {
    Write-log -head "error" -color "red" -msg "Unable to find last login for user $userPath, skipping..."; 
    continue;
  }
  
  $userLoginAge = (New-Timespan -Start $userLastLogin -End $today).Days;
  Write-log -msg "User $userPath last logged in $userLoginAge days ago";
  
  # If account is over $age days old delete
  if ($userLoginAge -gt $age) {
    Write-log -head "doing" -color "DarkCyan" -msg "User $userPath will now be deleted";
    if ($dryrun) {
      Write-log -head "trial" -color "DarkGray" -msg "this is a dryrun no changes have been made";
      continue;
    }
    $user.Delete();
  } else {
    Write-log -color "DarkCyan" -msg "User $userPath will not be deleted today";
  }
}

# Update user list for new total
$users = Get-WmiObject Win32_UserProfile;
Write-Log -msg "There are now $($users.length) users";
