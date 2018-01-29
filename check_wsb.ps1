<#
.SYNOPSIS
	Check Windows Server Backup last scheduled job status.
.DESCRIPTION
	Check Windows Server Backup and returns Nagios output and code.
PARAMETER Hours
	Number of hours since now to check for backup jobs.
	Default 48.
.OUTPUTS
    OK: All last backups jobs within $Hours successful.
    CRITICAL: Backup job failed.
.EXAMPLE
	.\check_wsb.ps1 -Hours 96
.NOTES 
	Author:	Juan Granados 
	Date:	December 2017
#>
Param(	
    [Parameter(Mandatory=$false,Position=0)] 
	[ValidateNotNullOrEmpty()]
	[int]$Hours=48
)

#Load PSSnapin for Windows 2008 / R2
$OperatingSystemVersion = (Get-WmiObject win32_operatingsystem).version
if (($OperatingSystemVersion -match "6.0") -or ($OperatingSystemVersion -match "6.1")){
    Add-PSSnapin windows.serverbackup
}

# Get backup status
try{
    $BackupSummary = Get-WBSummary -ErrorAction Stop
}catch{
    Write-Output "UNKNOWN: Could not get Windows Server Backup information. Try running in PowerShell console: Add-WindowsFeature -Name Backup-Tools | NumberOfVersions=0;;;;"
    $host.SetShouldExit(3)
}
if ($BackupSummary){
    # Check last backup
    $LastSuccessfulBackupTime = ($BackupSummary.LastSuccessfulBackupTime).Date
    # If there is a last backup
    If ($LastSuccessfulBackupTime){
        # Get number of backup versions
        $PerfmonOutput = " | NumberOfVersions=$($BackupSummary.NumberOfVersions);;;;"
        # If last backup has been performed in time and its result is ok.
        If ( (($BackupSummary.LastSuccessfulBackupTime).Date -ge (get-date).AddHours(-$($Hours))) -and $BackupSummary.LastBackupResultHR -eq '0'){
            Write-Output "OK: last backup date $($BackupSummary.LastSuccessfulBackupTime). $($BackupSummary.NumberOfVersions) versions stored.$($PerfmonOutput)"
            $host.SetShouldExit(0)
        }
        # If last backup has not been performed in time or its result is not ok.
        Else{
            if ($BackupSummary.DetailedMessage){
                Write-Output "CRITICAL: Last backup result on error: $($BackupSummary.DetailedMessage) Last successful backup date: $($BackupSummary.LastSuccessfulBackupTime).$($PerfmonOutput)"            
            }
            else{
                Write-Output "CRITICAL: Last backup result on unspecified error. Last successful backup date: $($BackupSummary.LastSuccessfulBackupTime).$($PerfmonOutput)"
            }
            $host.SetShouldExit(2)
        }
    }
    else{
        Write-Output "CRITICAL: There is not any successful backup yet. | NumberOfVersions=0;;;;"
        $host.SetShouldExit(2)
    }
}
else{
    Write-Output "UNKNOWN: Could not get Windows Server Backup information. | NumberOfVersions=0;;;;"
    $host.SetShouldExit(3)
}
