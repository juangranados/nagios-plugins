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
.EXAMPLE
	.\Get-ADReplication.ps1 -Warning 5 -Critical 10
.NOTES 
	Author:	Juan Granados 
	Date:	December 2017
#>
Param(
		[Parameter(Mandatory=$false,Position=0)] 
		[ValidateNotNullOrEmpty()]
		[int]$Warning=1,
		[Parameter(Mandatory=$false,Position=1)] 
		[ValidateNotNullOrEmpty()]
		[int]$Critical=5
)
# Variables
$SyncErrors=0
$NagiosStatus = 0
$NagiosOutput = ""
$Syncs = 0

# Get AD Replication Status for this DC
$SyncResults = Get-WmiObject -Namespace root\MicrosoftActiveDirectory -Class MSAD_ReplNeighbor -ComputerName $env:COMPUTERNAME |
	select SourceDsaCN, NamingContextDN, LastSyncResult, NumConsecutiveSyncFailures, @{N="LastSyncAttempt"; E={$_.ConvertToDateTime($_.TimeOfLastSyncAttempt)}}, @{N="LastSyncSuccess"; E={$_.ConvertToDateTime($_.TimeOfLastSyncSuccess)}} 

# Process result
foreach ($SyncResult in $SyncResults)
{
	if ($SyncResult.LastSyncResult -gt 0){
		$NagiosOutput += "$($SyncResult.NumConsecutiveSyncFailures) failed sync with DC $($SyncResult.SourceDsaCN) on $($SyncResult.NamingContextDN) at $($SyncResult.LastSyncAttempt), last success sync at $($SyncResult.LastSyncSuccess)."
		$SyncErrors++
		if ($SyncErrors -eq $Warning){
			$NagiosStatus = 1
		}
		elseif ($SyncErrors -eq $Critical) {
			$NagiosStatus = 2
		}			
	}
	else{
		$Syncs++
	}
}
# Nagios Output
$NagiosOutput += " | Syncs=$($Syncs);;;; SyncErrors=$($SyncErrors);$Warning;$Critical;;"
if ($NagiosStatus -eq 2) {
	Write-Host "CRITICAL: Replication error: $($NagiosOutput)"
    $host.SetShouldExit(2)
} 
elseif ($NagiosStatus -eq 1) {
	Write-Host "WARNING: Replication error: $($NagiosOutput)"
    $host.SetShouldExit(1)
} 
else{
	Write-Host "OK: replication is up and running.$($NagiosOutput)"
	$host.SetShouldExit(0)
}