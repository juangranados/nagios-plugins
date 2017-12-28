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
.EXAMPLE
.NOTES 
	Author:	Juan Granados 
	Date:	December 2017
#>

$Services = Get-CimInstance win32_service -Filter "startmode = 'auto' AND state != 'running' AND exitcode != 0"  | select name, startname, exitcode
$ServicesRunning = Get-CimInstance win32_service -Filter "state = 'running'"
if ([string]::IsNullOrEmpty($Services)){
    Write-Output "OK: All services running | ServicesRunning=$($ServicesRunning.Count);0;0;0;0"
    $host.SetShouldExit(0)
}
else{
    $ServicesStopped=""
    ForEach ($Service in $Services){
        Start-Service $($Service.Name) -ErrorAction SilentlyContinue | Out-Null
        if ($(Get-Service -Name $($Service.Name)).Status -eq "running"){
            $ServicesStopped += "$($Service.Name)(Started manually),"
            If ($ExitCode -eq 0){
                $ExitCode = 1
            }
        }
        Else{
            $ServicesStopped += "$($Service.Name)(Stopped),"
            $ExitCode = 2
        }
    }
    If ($ExitCode -eq 2){
        Write-Output "CRITICAL: Service(s) stopped: $($ServicesStopped.TrimEnd(",")) | ServicesRunning=$($ServicesRunning.Count);0;0;0;0"
        $host.SetShouldExit(2)
    }
    Else{
        Write-Output "WARNING: Service(s) stopped: $($ServicesStopped.TrimEnd(",")) | ServicesRunning=$($ServicesRunning.Count);0;0;0;0"
        $host.SetShouldExit(1)
    }
}
