<#
.SYNOPSIS
	Check IIS Website and AppPool status.
.DESCRIPTION
	Check IIS Website and AppPool status and try to start stopped ones.
.PARAMETER Websites
	Websites to check status.
	Default All.
.PARAMETER AppPools
	AppPools to check status.
	Default All.
.OUTPUTS
	OK: All Websites and AppPools Running.
	WARNING: Websites or AppPools stopped, but started manually.
	CRITICAL: Websites or AppPools stopped and could not started.
.EXAMPLE
    Check a list of Websites and AppPools 
	.\check_iis.ps1 -Websites 'site 1','site 2','site 3' -AppPools 'apppool 1','app2','test 1'
    
    Check all Websites and AppPools 
    .\check_iis.ps1
.NOTES 
	Author:	Juan Granados 
#>
Param(	
	[Parameter(Mandatory=$false,Position=0)] 
	[ValidateNotNullOrEmpty()]
	$Websites="All",
	[Parameter(Mandatory=$false,Position=1)] 
	[ValidateNotNullOrEmpty()]
	$AppPools="All"
)

$ExitCode = "0"
$Output = ""
$WebsitesRunning = (Get-WebsiteState | Where-Object { ($_.value -eq "Started") }).Count
$AppPoolsRunning = (Get-WebAppPoolState | Where-Object { ($_.value -eq "Started") }).Count
$WebsitesTotal = (Get-WebsiteState).Count
$AppPoolTotal = (Get-WebAppPoolState).Count
$StoppedWebsites = $null
$StoppedAppPools = $null

Function Get-Status ($Names,$List,$Type,[ref]$ExitCode) {
	$ReturnOutput=""
	foreach ($Item in $List) {
		if (($Names -eq "All") -or ($Names -contains $Item.Name)) {
		    if ($Type -eq "Websites"){
			Start-Website -Name $Item.Name -ErrorAction SilentlyContinue
			$Result = (Get-WebsiteState -Name $Item.Name).value
		    } else {
			Start-WebAppPool -Name $Item.Name -ErrorAction SilentlyContinue
			$Result = (Get-WebAppPoolState -Name $Item.Name).value
		    }
		    if ($Result -eq "Started") {
			if ($ExitCode.Value -eq 0) {
			    $ExitCode.Value = "1"
			}
			if ($ReturnOutput -eq "") {
			   $ReturnOutput += "$($Type) not started: $($Item.Name)(Started manually). " 
			} else {
			    $ReturnOutput +="$($Item.Name)(Started manually). "
			}
		    } else {
			$ExitCode.Value = "2"
			If ($ReturnOutput -eq "") {
			   $ReturnOutput += "$($Type) not started: $($Item.Name)(Stopped). " 
			} else{
			    $ReturnOutput +="$($Item.Name)(Stopped). "
			}
		    }
		}
	}
	Return $ReturnOutput
}
$StoppedWebsites = Get-WebsiteState | Where-Object { ($_.value -ne "Started") } | % { return @{($_.itemxpath -split ("'"))[1]="$($_.value)" } } | % getEnumerator
if ($StoppedWebsites) {
	$Output += Get-Status $Websites $StoppedWebsites "Websites" ([ref]$ExitCode)
}
$StoppedAppPools = Get-WebAppPoolState | Where-Object { ($_.value -ne "Started") } | % { return @{($_.itemxpath -split ("'"))[1]="$($_.value)" } } | % getEnumerator
if ($StoppedAppPools) {
	$Output += Get-Status $AppPools $StoppedAppPools "AppPools" ([ref]$ExitCode)
}

$Output += "| WebsitesRunning=$($WebsitesRunning);0;0;0;$($WebsitesTotal) AppPoolsRunning=$($AppPoolsRunning);0;0;0;$($AppPoolTotal)"

if ($ExitCode -eq 2) {
	Write-Output "CRITICAL: $($Output)"
	Exit(2)
} elseif ($ExitCode -eq 1) {
	Write-Output "WARNING: $($Output)"
	Exit(1)
} else {
	Write-Output "OK: All Websites and AppPools Running. $($Output)"
	Exit(0)
}
