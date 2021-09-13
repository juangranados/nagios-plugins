<#
.SYNOPSIS
	Check all automatic services are running and try to start stopped ones.
.DESCRIPTION
	Check all automatic services are running and returns Nagios output and code.
	Try to start stopped services manually.
.OUTPUTS
	OK: All services running.
	WARNING: Services stopped but started manually.
	CRITICAL: Services stopped and could not started.
.NOTES 
	Author:	Juan Granados
#>

$Services = Get-CimInstance win32_service -Filter "startmode = 'auto' AND state != 'running' AND exitcode != 0"  | select name, startname, exitcode
$ServicesRunning = Get-CimInstance win32_service -Filter "state = 'running'"
if ([string]::IsNullOrEmpty($Services)) {
    Write-Output "OK: All services running | ServicesRunning=$($ServicesRunning.Count);0;0;0;0"
    Exit(0)
} else {
    $ServicesStopped=""
    foreach ($Service in $Services){
        Start-Service $($Service.Name) -ErrorAction SilentlyContinue | Out-Null
        if ($(Get-Service -Name $($Service.Name)).Status -eq "running") {
            $ServicesStopped += "$($Service.Name)(Started manually),"
            if ($ExitCode -eq 0) {
                $ExitCode = 1
            }
        } else {
            $ServicesStopped += "$($Service.Name)(Stopped),"
            $ExitCode = 2
        }
    }
    if ($ExitCode -eq 2) {
        Write-Output "CRITICAL: Service(s) stopped: $($ServicesStopped.TrimEnd(",")) | ServicesRunning=$($ServicesRunning.Count);0;0;0;0"
        Exit(2)
    } else {
        Write-Output "WARNING: Service(s) stopped: $($ServicesStopped.TrimEnd(",")) | ServicesRunning=$($ServicesRunning.Count);0;0;0;0"
        Exit(1)
    }
}
