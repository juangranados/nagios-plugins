<#
.SYNOPSIS
	Check version Icinga Windows Agent.
.DESCRIPTION
	Check version Icinga Windows Agent and optionally updates it.
.OUTPUTS
    OK: Version up to date.
    WARNING: Version needs updating.
    CRITICAL: Error updating agent.
.PARAMETER downloadURL
    Icinga agent last version download url.
    Default: "http://packages.icinga.com/windows/Icinga2-v2.11.11-x86_64.msi"
.PARAMETER changeLoginToSystem
    Changes login service from Network Service to System.
.EXAMPLE
    install_icinga.ps1 -downloadURL "http://packages.icinga.com/windows/Icinga2-v2.11.11-x86_64.msi" -changeLoginToSystem
.NOTES 
	Author:	Juan Granados
#>
Param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$downloadURL = "http://packages.icinga.com/windows/Icinga2-v2.11.11-x86_64.msi",
    [Parameter()]
    [switch]$changeLoginToSystem
)
#Requires -RunAsAdministrator

Function StartProcess {
    param([string]$executable, [bool]$flushNewLines, [string]$arguments);

    $processData = New-Object System.Diagnostics.ProcessStartInfo;
    $processData.FileName = $executable;
    $processData.RedirectStandardError = $true;
    $processData.RedirectStandardOutput = $true;
    $processData.UseShellExecute = $false;
    $processData.Arguments = $arguments;
    $process = New-Object System.Diagnostics.Process;
    $process.StartInfo = $processData;
    $process.Start() | Out-Null;
    $stdout = $process.StandardOutput.ReadToEnd();
    $stderr = $process.StandardError.ReadToEnd();
    $process.WaitForExit();

    if ($flushNewLines) {
        $stdout = $stdout.Replace("`n", '').Replace("`r", '');
        $stderr = $stderr.Replace("`n", '').Replace("`r", '');
    }
    else {
        if ($stdout.Contains("`n")) {
            $stdout = $stdout.Substring(0, $stdout.LastIndexOf("`n"));
        }
    }

    $r = @{};
    $r.Add('message', $stdout);
    $r.Add('error', $stderr);
    $r.Add('exitcode', $process.ExitCode);

    return $r;
}
Start-Transcript "$($PSScriptRoot)\install_icinga2.txt"
$localInstaller = "$($PSScriptRoot)\icinga2.msi"
Write-Host "Downloading icinga from $downloadURL"
(New-Object System.Net.WebClient).DownloadFile($downloadURL, $localInstaller)
Write-Host "Unlocking $localInstaller"
Unblock-File $localInstaller
Write-Host "Installing icinga"
$R = StartProcess "msiexec.exe" $false "/I $localInstaller /qn /norestart"
if ($R.exitcode -ne 0) {
    Write-Host "Error installing Icinga2"
    Write-Host $R.error
    Remove-Item $localInstaller -Force
    Stop-Transcript
    Exit(2)
}
Write-Host "Removing $localInstaller"
Remove-Item $localInstaller -Force
if ($changeLoginToSystem) {
    Write-Host "Change servide login to System"
    (Get-Service icinga2).WaitForStatus('Running')
    $changeServiceResult = Get-CimInstance win32_service -filter "name='icinga2'" | Invoke-CimMethod -Name Change -Arguments @{StartName = "LocalSystem" }
    if ($changeServiceResult.ReturnValue -ne 0) {
        Write-Host "Error changing icinga2 login to System"
        Stop-Transcript
        Exit(2)
    }
    Write-Host "Restarting icinga service"
    Restart-Service icinga2
}
Write-Output "OK: Version updated to: $((Get-Item 'C:\Program Files\ICINGA2\sbin\icinga2.exe').VersionInfo.ProductVersion)"
Stop-Transcript
Exit(0)