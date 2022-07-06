<#
.SYNOPSIS
	Check AD Replication in a DC Server.
.DESCRIPTION
	Check AD Replication in a DC Server and returns Nagios output and code.
.PARAMETER Warning
	Number of failed replications for warning treshold.
	Default 1.
.PARAMETER Critical
	Number of failed replications for critical treshold.
	Default 5.
.OUTPUTS
	OK: AD replication successful.
	WARNING: Failed replications equal to Warning treshold.
	CRITICAL: Failed replications equal to Critical treshold.
.EXAMPLE
	.\Get-ADReplication.ps1 -Warning 5 -Critical 10
.NOTES 
	Author:	Juan Granados
#>
Param(
	[Parameter(Mandatory = $false, Position = 0)] 
	[ValidateNotNullOrEmpty()]
	[int]$Warning = 1,
	[Parameter(Mandatory = $false, Position = 1)] 
	[ValidateNotNullOrEmpty()]
	[int]$Critical = 5
)
# Variables
$SyncErrors = 0
$NagiosStatus = 0
$NagiosOutput = ""
$Syncs = 0
if (!(Get-ADDomainController -filter *).count) {
	Write-Host "OK: There is only one domain controller. | Syncs=0;;;; SyncErrors=0;$Warning;$Critical;;"
	Exit(0)
}
# Get AD Replication Status for this DC
$SyncResults = Get-WmiObject -Namespace root\MicrosoftActiveDirectory -Class MSAD_ReplNeighbor -ComputerName $env:COMPUTERNAME |
Select-Object SourceDsaCN, NamingContextDN, LastSyncResult, NumConsecutiveSyncFailures, @{N = "LastSyncAttempt"; E = { $_.ConvertToDateTime($_.TimeOfLastSyncAttempt) } }, @{N = "LastSyncSuccess"; E = { $_.ConvertToDateTime($_.TimeOfLastSyncSuccess) } } 
if (-not $SyncResults) {
	Write-Host "UNKNOWN - Can not check DC syncs. Maybe WMI is not working properly."
	Exit(3)
}
# Process result
foreach ($SyncResult in $SyncResults) {
	if ($SyncResult.LastSyncResult -gt 0) {
		$NagiosOutput += "$($SyncResult.NumConsecutiveSyncFailures) failed sync with DC $($SyncResult.SourceDsaCN) on $($SyncResult.NamingContextDN) at $($SyncResult.LastSyncAttempt), last success sync at $($SyncResult.LastSyncSuccess)."
		$SyncErrors++
		if ($SyncErrors -eq $Warning) {
			$NagiosStatus = 1
		}
		elseif ($SyncErrors -eq $Critical) {
			$NagiosStatus = 2
		}			
	}
 else {
		$Syncs++
	}
}
$SysvolStatus = Get-WMIObject -ComputerName $env:COMPUTERNAME -Namespace "root/microsoftdfs" -Class "dfsrreplicatedfolderinfo" -Filter "ReplicatedFolderName = 'SYSVOL Share'" | Select-Object State
if ($SysvolStatus.State) {
	switch ( $SysvolStatus.State ) {
		0 { $NagiosOutput += " CRITICAL - Sysvol Uninitialized."; $NagiosStatus = 2; }
		1 { $NagiosOutput += " WARNING - Sysvol Initialized."; if ($NagiosStatus -eq 0) { $NagiosStatus = 1 } }
		2 { $NagiosOutput += " WARNING - Sysvol on Initial Sync."; if ($NagiosStatus -eq 0) { $NagiosStatus = 1 } }
		3 { $NagiosOutput += " WARNING - Sysvol on Auto Recovery."; if ($NagiosStatus -eq 0) { $NagiosStatus = 1 } }
		4 { $NagiosOutput += " Sysvol is OK." }
		5 { $NagiosOutput += " CRITICAL - Sysvol has an Error."; $NagiosStatus = 2; }
	}
}
else {
	$NagiosOutput = "UNKNOWN - Can not chech Sysvol status. | Syncs=$($Syncs);;;; SyncErrors=$($SyncErrors);$Warning;$Critical;;"
	Write-Host $NagiosOutput
	Exit(3)
}
$NagiosOutput += " | Syncs=$($Syncs);;;; SyncErrors=$($SyncErrors);$Warning;$Critical;;"
if ($NagiosStatus -eq 2) {
	Write-Host "CRITICAL: Replication error: $($NagiosOutput)"
	Exit(2)
}
elseif ($NagiosStatus -eq 1) {
	Write-Host "WARNING: Replication error: $($NagiosOutput)"
	Exit(1)
}
else {
	Write-Host "OK: replication is up and running.$($NagiosOutput)"
	Exit(0)
}
