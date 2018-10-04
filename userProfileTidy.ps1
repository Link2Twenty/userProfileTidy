<#
Powershell script to delete idle roaming profiles from a windows computer

Usage: userProfileTidy.ps1 [OPTION...]
-a, -age          Set minimum age of profiles, in days (required)
-d, -debug        Output process to console for debugging
-dryrun           Run through process but do not commit any changes, debug implied
-?, -h, -help     Display help screen

userProfileTidy.ps1 -age 28

@author Andrew Bone <https://github.com/link2twenty>
@licence MIT
@version 0.0.1
#>

# Default value for age
# Roaming accounts over this age will be removed
$age = 30;

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
  Write-Host "Usage: userProfileTidy.ps1 [OPTION...]"
  Write-Host "-a, -age          Set minimum age of profiles, in days (required)"
  Write-Host "-d, -debug        Output process to console for debugging"
  Write-Host "-dryrun           Run through process but do not commit any changes, debug implied"
  Write-Host "-?, -h, -help     Display help screen"
  exit 0
}

# Sets $age depending on arguemets
function Set-Age($age) {
  if (!($age -is [int])) {
    Write-Log -head "error" -color "red" -msg "age must be numeric";
    exit 1;
  }
  $script:age = $age;
}

# Check all arguments and do appropriate actions
for ($i = 0; $i -lt $args.Length; $i++) {
  switch ($args[$i]) {
    "-a" {Set-Age -age $args[$i + 1]};
    "-age" {Set-Age -age $args[$i + 1]};
    "--age" {Set-Age -age $args[$i + 1]};
    "-?" {Show-Help};
    "-h" {Show-Help};
    "-help" {Show-Help};
    "--help" {Show-Help};
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
  # If account is not Roaming skip
  if (!$user.RoamingConfigured) {
    Write-log -msg "User $userPath is local, skipping..."; 
    continue;
  };
  Write-log -head "start" -color "green" -msg "User $userPath has a roaming profile";
  # Calculate LoginAge based on LastLogin 
  $userLastLogin = Get-Date -Year (($user.LastUseTime).Substring(0, 4)) -Month (($user.LastUseTime).Substring(4, 2)) -Day (($user.LastUseTime).Substring(6, 2));
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