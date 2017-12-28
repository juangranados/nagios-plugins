<#
.SYNOPSIS
	Check Backup Exec last scheduled job status.
.DESCRIPTION
	Check Backup Exec last scheduled job status and returns Nagios output and code.
.PARAMETER Hours
	Number of hours since now to check for backup jobs.
	Default 48.
.OUTPUTS
    OK: All last backups jobs within $Hours successful.
    WARNING: Backup job status succeeded with exceptions.
    CRITICAL: Backup job failed.
.EXAMPLE
	.\check_bejobs.ps1 -Hours 96
.NOTES 
	Author:	Juan Granados 
	Date:	December 2017
#>
Param(	
    [Parameter(Mandatory=$false,Position=0)] 
	[ValidateNotNullOrEmpty()]
	[int]$Hours=48
)
if (Get-Module -ListAvailable -Name BEMCLI) {
    Import-Module BEMCLI
} else {
    Write-Output "UNKNOWN: Module BEMCLI does not exist."
    Exit 3
}
$OkStatus = 'Succeeded','Active'
$StartTime = Get-Date
$Jobs = Get-BEJobHistory | Where-Object { ($_.JobType -eq "Backup") -and ($_.StartTime -ge $StartTime.AddHours(-$Hours))} | Sort-Object -Property {$_.StartTime -as [datetime]} -Descending
$ExitCode = 0
$Output=""
$TotalDataSizeBytes = 0
$SuccessJobs = 0
$FailedJobs = 0
$JobsNames = New-Object System.Collections.ArrayList
ForEach ($Job in $Jobs){
    if ( $JobsNames -contains $Job.Name){
        continue
    }
    else{
        $JobsNames.Add($Job.Name) | Out-Null
    }
    $TotalDataSizeBytes += $Job.TotalDataSizeBytes

    if ($Job.JobStatus -eq "SucceededWithExceptions"){
        if ($ExitCode -lt 1){
            $ExitCode = 1
        }
        $SuccessJobs++
    }
    elseIf (!($OkStatus -match $Job.JobStatus)){
        $ExitCode = 2
        $FailedJobs++
    }
    else{
        $SuccessJobs++
        continue
    }
    $Output += "$($Job.Name) exited with status $($Job.JobStatus) at $($Job.EndTime)."
    
}

$PerformanceOutput = " | SuccessJobs=$($SuccessJobs);;;; FailedJobs=$($FailedJobs);1;1;; BackupSize=$([math]::round($TotalDataSizeBytes/1GB,3))GB;;;;"

If ($ExitCode -eq 0){
    Write-Host "All last backups jobs within $($Hours) hours successful.$($PerformanceOutput)"
    $host.SetShouldExit(0)
}

ElseIf ($ExitCode -eq 1){
    Write-Host "WARNING: $($Output)$($PerformanceOutput)"
    $host.SetShouldExit(1)
}
Else{
	Write-Host "CRITICAL: $($Output)$($PerformanceOutput)"
	$host.SetShouldExit(2)
}
