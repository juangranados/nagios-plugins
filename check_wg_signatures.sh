#!/bin/bash
# check_wg_signatures for Nagios
# Version: 1.0
# March 2022 - Juan Granados
#---------------------------------------------------
# This plugin checks Gateway Antivirus Service and/or Intrusion Prevention Service 
# update time of Watchguard device.
# Usage: check_wg_signatures.sh [options]
# -h | --host: ip of device.
# -w | --warning: warning hours since last update. Default 24.
# -c | --critical:  critical hours since last update. Default 48.
# -a | --antivirus: checks only Antivirus Service.
# -i | --intrusion: checks only Intrusion Prevention Service.
# -v | --version: snmp version. Default 2. Depends on version you must specify:
#   2: -s | --string: snmp community string. Default public.
#   3: -u | --user: user. -p | --pass: password.
# Example: check_wg_signatures.sh -h 192.168.2.100 -s publicsnmp -a
# Example: check_wg_signatures.sh -h 192.168.2.100 -v 3 -u read -p 1234567789 -i
#---------------------------------------------------
# Reference https://www.watchguard.com/help/docs/help-center/en-US/Content/en-US/Fireware/basicadmin/snmp_mibs_details_c.html
#---------------------------------------------------

# Default variables
warning=24
critical=48
version="2"
community="public"
timeout="10"
wgInfoGavService="1.3.6.1.4.1.3097.6.1.3.0"
wgInfoIpsService="1.3.6.1.4.1.3097.6.1.4.0"
exitCode=0
intrusion=1
antivirus=1
output=""

# Process arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --warning*|-w*)
      if [[ "$1" != *=* ]]; then shift; fi
      warning="${1#*=}"
      ;;
    --critical*|-c*)
      if [[ "$1" != *=* ]]; then shift; fi
      critical="${1#*=}"
      ;;
    --host*|-h*)
      if [[ "$1" != *=* ]]; then shift; fi
      host="${1#*=}"
      ;;
    --user*|-u*)
      if [[ "$1" != *=* ]]; then shift; fi
      user="${1#*=}"
      ;;
    --pass*|-p*)
      if [[ "$1" != *=* ]]; then shift; fi
      pass="${1#*=}"
      ;;
    --version*|-v*)
      if [[ "$1" != *=* ]]; then shift; fi
      version="${1#*=}"
      ;;
    --string*|-s*)
      if [[ "$1" != *=* ]]; then shift; fi
      community="${1#*=}"
      ;;
      intrusion--*|-i*)
      if [[ "$1" != *=* ]]; then shift; fi
      intrusion=1
      antivirus=0
      ;;
      antivirus--*|-a*)
      if [[ "$1" != *=* ]]; then shift; fi
      intrusion=0
      antivirus=1
      ;;
    --help)
      echo "Usage: check_wg_signatures.sh [options]"
      echo "   -h | --host: ip of device. Ex: 192.168.2.100"
      echo "   -w | --warning: warning hours since last update. Default 24."
      echo "   -c | --critical: critical hours since last update. Default 48."
      echo "   -i | --intrusion: checks only Intrusion Prevention Service."
      echo "   -a | --antivirus: checks only Gateway Antivirus Service."
      echo "   -v | --version: snmp version. Default 2. Depends on version you must specify:"
      echo "       2: -s | --string: snmp community string. Default public"
      echo "       3: -u | --user: user. -p | --pass: password"
      echo "Example: check_wg_signatures.sh -h 192.168.2.100 -s publicsnmp -a"
      echo "Example: check_wg_signatures.sh -h 192.168.2.100 -v 3 -u read -p 1234567789 -i"
      exit 3
      ;;
    *)
      >&2 printf "Error: Invalid argument: $1\n"
      exit 3
      ;;
  esac
  shift
done

# Check arguments
if ! [[ $(command -v snmpget) ]]
then
    echo "snmpget could not be found. Please install it and try again"
    exit 3
fi
if ! [[ $warning =~ $re ]]
then
    echo "Unknown: warning must be a number"
    exit 3
fi
if ! [[ $critical =~ $re ]]
then
    echo "Unknown: critical must be a number"
    exit 3
fi

if [[ -z $host ]]
then
    echo "Unknown: host can not be empty"
    exit 3
fi
if [[ $version -eq 3 && ( -z $user || -z $pass) ]]
then
    echo "Unknown: username and/or password can not be empty"
    exit 3
fi
if [[ $(echo $warning'>'$critical | bc -l) -eq 1 ]]
then
    echo "Unknown: Critical must be higher than warning"
    exit 3
fi

# SNMP Command sintax
if [[ $version -eq "2" ]]
then
	args=" -OQne -v 2c -c $community -t $timeout"
elif [[ $version -eq "3" ]]
then
	args=" -OQne -v 3 -u $user -A $pass -l authNoPriv -a MD5 -t $timeout"
else
  echo "Unknown: snmp version must be 2 or 3"
  exit 3
fi

# Critical and warning dates
criticalDate=`date -d "-$critical hour" +%s`
warningDate=`date -d "-$warning hour" +%s`

# Run SNMP commands and check
if [[ $antivirus -eq 1 ]]
then
  avDate=`snmpget $args $host $wgInfoGavService 2> /dev/null | grep -oP '\(\K[^\)]+'`
  if [[ -z $avDate ]]
  then 
    echo "Unknown: could not get update time of the Gateway Antivirus Service"
    exit 3
  fi
  avDateS=`date -d "$avDate" +%s`

  if [[ $avDateS -lt $warningDate ]]
  then
    exitCode=1
  fi
  if [[ $avDateS -lt $criticalDate ]]
  then
    exitCode=2
  fi
  output="Gateway Antivirus Service date: $avDate"
fi
if [[ $intrusion -eq 1 ]]
then
  ipDate=`snmpget $args $host $wgInfoIpsService 2> /dev/null | grep -oP '\(\K[^\)]+'`
  if [[ -z $ipDate ]]
  then 
    echo "Unknown: could not get update time of the  Intrusion Prevention Service"
    exit 3
  fi
  ipDateS=`date -d "$ipDate" +%s`
  if [[ ($ipDateS -lt $warningDate) && ($exitCode -eq 0) ]]
  then
    exitCode=1
  fi
  if [[ $ipDateS -lt $criticalDate ]]
  then
    exitCode=2
  fi
  output="${output:+$output. }Intrusion Prevention Service date: $ipDate."
fi

# Exit
if [[ $exitCode -eq 0 ]]
then
  echo "Ok. $output"
  exit 0
elif [[ $exitCode -eq 1 ]]
then
  echo "Warning. $output"
  exit 1
else
  echo "Critical. $output"
  exit 2
fi