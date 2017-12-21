$Services = Get-CimInstance win32_service -Filter "startmode = 'auto' AND state != 'running' AND exitcode != 0"  | select name, startname, exitcode
$ServicesRunning = Get-CimInstance win32_service -Filter "state = 'running'"
if ([string]::IsNullOrEmpty($Services)){
    Write-Output "OK: All services running | ServicesRunning=$($ServicesRunning.Count)1;1;;;"
    $host.SetShouldExit(0)
}
else{
    $ServicesStopped=""
    ForEach ($Service in $Services){
        $ServicesStopped += "$($Service.Name),"
    }
    Write-Output "CRITICAL: Service(s) stopped: $($ServicesStopped.TrimEnd(",")) | ServicesRunning=$($ServicesRunning.Count);1;1;;"
    $host.SetShouldExit(2);
}
