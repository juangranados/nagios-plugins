<#
.SYNOPSIS
	Check Azure AD Connect Sync.
.DESCRIPTION
	Check Azure AD Connect Sync status and returns Nagios output and code.
.PARAMETER Hours
	Hours since the last synchronization.
	Default: 3
.OUTPUTS
	OK: Azure AD Connect Sync sync cycle enabled and not synced within last -Hours.
	WARNING: Azure AD Connect Sync sync cycle enabled and not synced within last -Hours.
	CRITICAL: Azure AD Connect Sync sync cycle not enabled.
.NOTES 
	Author:	Juan Granados 
	Date:	January 2018
#>
Param(	
	[Parameter(Mandatory=$false,Position=0)] 
	[ValidateNotNullOrEmpty()]
	[int]$Hours=3
)

$Output = ""
$ExitCode = 0

$pingEvents = Get-EventLog -LogName "Application" -Source "Directory Synchronization" -InstanceId 654  -After (Get-Date).AddHours(-$($Hours)) -ErrorAction SilentlyContinue |
	Sort-Object { $_.Time } -Descending
if ($pingEvents -ne $null) {
	$Output = "Latest heart beat event (within last $($Hours) hours). Time $($pingEvents[0].TimeWritten)."
}
else{
	$Output = "No ping event found within last $($Hours) hours."
	$ExitCode = 1
}

$ADSyncScheduler = Get-ADSyncScheduler
If (!$ADSyncScheduler.SyncCycleEnabled){
	$ExitCode = 2
}

If ($ADSyncScheduler.StagingModeEnabled){
	$Output = "Server is in stand by mode. $($Output)"
}
Else{
	$Output = "Server is in active mode. $($Output)"
}

If ($ExitCode -eq 0){
	Write-Host "OK: Azure AD Connect Sync is up and running. $($Output)"
}
ElseIf($ExitCode -eq 1){
	Write-Host "WARNING: Azure AD Connect Sync is enabled, but not syncing. $($Output)"
}
ElseIf($ExitCode -eq 2){
	Write-Host "CRITICAL: Azure AD Connect Sync is disabled. $($Output)"
}

$Host.SetShouldExit($ExitCode)
