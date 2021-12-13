<#
.SYNOPSIS
    Check Windows disks fragmentation status.
.DESCRIPTION
    Check Windows disks fragmentation status.
    Optionally performs defragmentation.
.OUTPUTS
    OK: All disk fragmentation status is ok.
    WARNING: % of fragmentation equal to Warning treshold.
    CRITICAL: % of fragmentation equal to Critical treshold.
.PARAMETER warning
    % of fragmentation for warning treshold.
    Default System default.
.PARAMETER critical
    % of fragmentation for critical treshold.
    Default None.
.PARAMETER disks
    Disks to check fragmentation status.
    Default: all.
    Example: "C:","D:","F:"
.PARAMETER defrag
    Defrag disks if warning or critical.
    Default: false
.PARAMETER forceDefrag
    Defrag disks if free space is low.
    Default: false
.EXAMPLE
    Only checks all drives with system default warning treshold.
    check_diskdefragstatus.ps1
.EXAMPLE
    Checks all drives with 15 warning treshold and 40 critical treshold.
    check_diskdefragstatus.ps1 -warning 15 -critical 40
.EXAMPLE
    Checks only C and D drives with system default warning treshold and 50 critical treshold.
    check_diskdefragstatus.ps1 -disks "C:","D:" -critical 50
.EXAMPLE
    Checks C drive with system default warning treshold.
    If defragmentation status is greater than warning or critical treshold, it runs disk defragmentation.
    check_diskdefragstatus.ps1 -disks "C:" -defrag
.EXAMPLE
    Checks C drive with system default warning treshold.
    If defragmentation status is greater than warning or critical treshold, it runs disk defragmentation even C: disk free space is low.
    check_diskdefragstatus.ps1 -disks "C:" -defrag -forceDefrag
.NOTES 
	Author:	Juan Granados
#>

Param(
    [Parameter(Mandatory = $false, Position = 0)] 
    [ValidateRange(0, 100)]
    [int]$warning = 0,
    [Parameter(Mandatory = $false, Position = 1)] 
    [ValidateRange(0, 100)]
    [int]$critical = 0,
    [Parameter(Mandatory = $false, Position = 2)] 
    [ValidateNotNullOrEmpty()]
    [string[]]$disks = "all",
    [Parameter()] 
    [switch]$defrag,
    [Parameter()] 
    [switch]$forceDefrag
)
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
$global:nagiosStatus = 0
$global:nagiosOutput = ""

Function Defrag-Disk($diskToDefrag) {

    if ($forceDefrag) {
        Write-Verbose "Forcing $($diskToDefrag.DriveLetter) defragmentation"
        $result = $diskToDefrag.Defrag($true)
    }
    else {
        Write-Verbose "Performing $($diskToDefrag.DriveLetter) defragmentation"
        $result = $diskToDefrag.Defrag($false)    
    }
        
    if ($result.ReturnValue -eq 0) {
        Write-Verbose "Defragmentation successful"
        Write-Verbose "Current fragmentation is $($result.DefragAnalysis.FilePercentFragmentation)"
        $diskToDefrag.DefragResult = $result
        if (($critical -gt 0) -and ($result.DefragAnalysis.FilePercentFragmentation -gt $critical)) {
            Write-Verbose "Status is critical"
            $global:nagiosStatus = 2
        }
        elseif (($warning -eq 0 -and $result.DefragAnalysis.FilePercentFragmentation -gt 10) -or ( ($warning -gt 0) -and ($result.DefragAnalysis.FilePercentFragmentation -gt $warning))) {
            Write-Verbose "Status is warning"
            $global:nagiosStatus = 1
        }
    }
    else {
        Write-Output "CRITICAL: Error $($result.ReturnValue) defragmenting drive $($diskToDefrag.DriveLetter)"
        Write-Output "Check error codes: https://docs.microsoft.com/en-us/previous-versions/windows/desktop/vdswmi/defrag-method-in-class-win32-volume"
        Exit(2)
    }
    
    $global:nagiosOutput += "Disk $($diskToDefrag.DriveLetter) fragmentation is $($result.DefragAnalysis.FilePercentFragmentation)."
}

try {
    if ($disks -eq "all") {
        $drives = get-wmiobject win32_volume | Where-Object { $_.DriveType -eq 3 -and $_.DriveLetter -and (Get-WMIObject Win32_LogicalDiskToPartition | Select-Object Dependent) -match $_.DriveLetter }
    }
    else {
        foreach ($disk in $disks) {
            if (-not ($disk -match '[A-Za-z]:')) {
                Write-Output "UNKNOWN: Error $($drive) is not a valid disk unit. Expected N:, where N is drive unit. Example C: or D: or F:"
                Exit(3)
            }
        }
        $drives = get-wmiobject win32_volume | Where-Object { $_.DriveType -eq 3 -and $_.DriveLetter -in $disks }
    }
    if (-not ($drives)) {
        Write-Output "UNKNOWN: No drives found with get-wmiobject win32_volume command"
        Exit(3)
    }
    foreach ($drive in $drives) {
        Write-Verbose "Analizing drive $($drive.DriveLetter)"
        $result = $drive.DefragAnalysis()
        if ($result.ReturnValue -eq 0) {
            Write-Verbose "Current fragmentation is $($result.DefragAnalysis.FilePercentFragmentation)"
            $drive | Add-Member -NotePropertyName 'DefragResult' -NotePropertyValue $result
            if (($critical -gt 0) -and ($result.DefragAnalysis.FilePercentFragmentation -gt $critical)) {
                if (-not $defrag) {
                    Write-Verbose "Disk will not be defragmented. Status is critical"
                    $global:nagiosStatus = 2
                }
                else {
                    Defrag-Disk -diskToDefrag $drive
                    Continue
                }
            }
            elseif (($warning -eq 0 -and $result.DefragRecommended -eq "True") -or ( ($warning -gt 0) -and ($result.DefragAnalysis.FilePercentFragmentation -gt $warning))) {
                if (-not $defrag) {
                    Write-Verbose "Disk will not be defragmented. Status is warning"
                    $global:nagiosStatus = 1
                }
                else {
                    Defrag-Disk -diskToDefrag $drive
                    Continue
                }
            }
            $global:nagiosOutput += "Disk $($drive.DriveLetter) fragmentation is $($result.DefragAnalysis.FilePercentFragmentation)."
        }
        else {
            Write-Output "CRITICAL: Error $($result.ReturnValue) checking status of drive $($drive.DriveLetter)"
            Write-Output "Check error codes: https://docs.microsoft.com/en-us/previous-versions/windows/desktop/vdswmi/defraganalysis-method-in-class-win32-volume#return-value"
            Exit(2)
        }
    }
    
}
catch {
    Write-Output "CRITICAL: $($_.Exception.Message)"
    Exit(2)
}

$global:nagiosOutput += " |"
if ($warning -eq 0) {
    $warning = 10;
}
if ($critical -eq 0) {
    $critical = 50;
}

foreach ($drive in $drives) {
    $global:nagiosOutput += " $($drive.DriveLetter.TrimEnd(':'))=$($drive.DefragResult.DefragAnalysis.FilePercentFragmentation)%;$($warning);$($critical);0;100"
}

if ($global:nagiosStatus -eq 2) {
    Write-Output "CRITICAL: $($global:nagiosOutput)"
    Exit(2)
} 
elseif ($global:nagiosStatus -eq 1) {
    Write-Output "WARNING: $($global:nagiosOutput)"
    Exit(1)
} 
else {
    Write-Output "OK: disk fragmentation is correct.$($global:nagiosOutput)"
    Exit(0)
}