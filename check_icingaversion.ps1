<#
.SYNOPSIS
    Check version Icinga Windows Agent.
.DESCRIPTION
    Check version Icinga Windows Agent and optionally updates it.
.OUTPUTS
    OK: Version up to date.
    WARNING: Version needs updating.
    CRITICAL: Error updating agent.
.PARAMETER lastVersion
    Icinga agent last version.
    Default: "2.11.11"
.PARAMETER downloadURL
    Icinga agent last version download url.
    Default: "http://packages.icinga.com/windows/Icinga2-v2.11.11-x86_64.msi"
.PARAMETER update
    Updates agent without modify configuration. Requires script "install_icinga.ps1" in the same directory.
    Creates a scheduled task to run "install_icinga.ps1" in 2 minutes and updates agent.
.PARAMETER changeLoginToSystem
    Changes login service from Network Service to System after updating.
.EXAMPLE
    check_icingaversion.ps1 -lastVersion "2.11.11" -downloadURL "http://packages.icinga.com/windows/Icinga2-v2.11.11-x86_64.msi" -update -changeLoginToSystem
.NOTES 
    Author:	Juan Granados
#>
Param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$lastVersion = "2.11.11",
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$downloadURL = "http://packages.icinga.com/windows/Icinga2-v2.11.11-x86_64.msi",
    [Parameter()]
    [switch]$update,
    [Parameter()]
    [switch]$changeLoginToSystem
)
#Requires -RunAsAdministrator

SCHTASKS /delete /tn UpdateIcingaAgent /f 2> $null
$lastVersion = [version]($lastVersion)
$installedVersion = (Get-Item 'C:\Program Files\ICINGA2\sbin\icinga2.exe').VersionInfo.ProductVersion
if (-not $installedVersion) {
    Write-Host "UNKNOWN: Icinga Agent not found"
    Exit(3)
}
$installedVersion = $installedVersion -replace "v", ""
if ($installedVersion.IndexOf('-') -ne -1) {
    $installedVersion = $installedVersion.Substring(0, $installedVersion.IndexOf('-'))
}
$installedVersion = [version]($installedVersion)
if ($installedVersion -ge $lastVersion) {
    Write-Output "OK: Your version up to date: $InstalledVersion"
    Exit(0)
}
else {
    if ($update) {
        $installTime = $(Get-Date).AddMinutes(2).toString('HH:mm')
        if ($changeLoginToSystem) {
            SCHTASKS /create /sc once /tn "UpdateIcingaAgent" /st "$installTime" /tr "$($PsHome)\powershell.exe $($PSScriptRoot)\install_icinga.ps1 -downloadURL $downloadURL -changeLoginToSystem" /RU "NT AUTHORITY\SYSTEM" /RL HIGHEST
        }
        else {
            SCHTASKS /create /sc once /tn "UpdateIcingaAgent" /st "$installTime" /tr "$($PsHome)\powershell.exe $($PSScriptRoot)\install_icinga.ps1 -downloadURL $downloadURL" /RU "NT AUTHORITY\SYSTEM" /RL HIGHEST
        }
        Write-Output "WARNING: Installing new version: $($lastVersion.ToString()). Check again in a few minutes"
        Exit(1)
    }
    else {
        Write-Output "WARNING: Please update your version: $InstalledVersion. Last version: $($lastVersion.ToString())"
        Exit(1)
    }
}