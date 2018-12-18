# userProfileTidy
Powershell script to delete idle roaming profiles from a windows computer

```
Usage: userProfileTidy.ps1 [OPTION...]
-a, -age          Set minimum age of profiles, in days (required)
-d, -debug        Output process to console for debugging
-dryrun           Run through process but do not commit any changes, debug implied
-f, -force        Force culling, will remove local accounts with mismatched domain
-?, -h, -help     Display help screen
```
