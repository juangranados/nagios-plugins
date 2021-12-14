<#
.SYNOPSIS
    Check Veeam last result and last run of all jobs.
.DESCRIPTION
    Check Veeam last result and last run of all jobs.
.OUTPUTS
    OK: All jobs last result is Success.
    CRITICAL: Any job last result is warning or any job last run less than warning hours ago.
    CRITICAL: Any job last result is error or any job last run less than critical hours ago.
.PARAMETER warning
    Warning hours after last backup.
    Default 24.
.PARAMETER critical
    Warning hours after last backup.
    Default 48.
.PARAMETER jobs
    Jobs names to check.
    Default: all.
    Example: "Tape Backup","Hyper-V","Incremental backup"
.EXAMPLE
    Checks jobs by name with default warning treshold and 50h critical treshold.
    check_diskdefragstatus.ps1 -jobs "Tape Backup","Full Backup","Hyper-V Backup" -critical 50
.EXAMPLE
    Checks all jobs by name with 48h warning treshold and 96h critical treshold.
    check_diskdefragstatus.ps1 -warning 48 -critical 96
.NOTES 
	Author:	Juan Granados
#>
Param(
    [Parameter(Mandatory = $false, Position = 0)] 
    [int]$warning = 24,
    [Parameter(Mandatory = $false, Position = 1)] 
    [int]$critical = 48,
    [Parameter(Mandatory = $false, Position = 2)]
    [string[]]$jobs = "all"
)
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
$global:nagiosStatus = 0
$global:nagiosOutput = @()
$WarningPreference = 'SilentlyContinue'
Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue
function Get-JobStatus ([string]$name, [string]$result, [string]$state, [datetime]$lastRun) {
    $jobInfo = "Name: $name - Result: $result - State: $state - Last run: $("$($lastRun.ToShortDateString()) at $($lastRun.ToShortTimeString())")."
    Write-Verbose $jobInfo
    if (($result -ne 'Warning' -and $result -ne "Success") -or $lastRun -lt (Get-Date).AddHours(-$critical)) {
        $global:nagiosOutput += "Critical -> $jobInfo"
        $global:nagiosStatus = 2
    }
    elseif ($result -eq 'Warning' -or $lastRun -lt (Get-Date).AddHours(-$warning)) {
        $global:nagiosOutput += "Warning -> $jobInfo"
        $global:nagiosStatus = 1
    }
    else {
        $global:nagiosOutput += "Ok: -> $jobInfo"
    }   
}
try {
    Write-Verbose "Getting jobs"
    $computerJobs = Get-VBRJob
    $tapeJobs = Get-VBRTapeJob
}
catch {
    Write-Output "CRITICAL: $($_.Exception.Message)"
    Exit(2)
}
if ($jobs -ne "all") {
    foreach ($job in $jobs) {
        if (!($computerJobs.Name -like $job) -and !($tapeJobs.Name -like $job)) {
            Write-Output "CRITICAL: $job not detected"
            Exit(2)
        }
    }
}
if ($computerJobs.Length -gt 0) {
    foreach ($job in $computerJobs) {
        if ($jobs -eq "all" -or $jobs -like $job.Name) {
            Get-JobStatus $($job.Name) $($job.GetLastResult()) $($job.findlastsession().state) $($job.LatestRunLocal)
        }
    }
}
if ($tapeJobs.Length -gt 0) {
    foreach ($job in $tapeJobs) {
        if ($jobs -eq "all" -or $jobs -like $job.Name) {
            Get-JobStatus $($job.Name) $($job.LastResult) $($job.LastState) $((Get-VBRSession -Job $TapeJobS[0] -Last).EndTime)
        }
    }
}
if ($global:nagiosStatus -eq 2) {
    Write-Output "CRITICAL"
    Write-Output $global:nagiosOutput
    Exit(2)
}
if ($global:nagiosStatus -eq 1) {
    Write-Output "WARNING"
    Write-Output $global:nagiosOutput
    Exit(1)
}
if ($global:nagiosOutput.Length -eq 0) {
    Write-Output "UNKNOWN: No jobs found"
    Exit(3)
}
Write-Output "OK"
Write-Output $global:nagiosOutput
Exit(0)