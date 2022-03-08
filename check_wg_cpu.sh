#!/bin/bash
# check_wg_cpu for Nagios
# Version: 1.0
# March 2022 - Juan Granados
#---------------------------------------------------
# This plugin checks CPU usage of Watchguard device and returns CPU performance data.
# Usage: check_wg_cpu.sh [options]
# -h | --host: ip of device.
# -w | --warning: % of cpu warning. Default 90.
# -c | --critical: % of cpu critical. Default 100.
# -v | --version: snmp version. Default 2. Depends on version you must specify:
#   2: -s | --string: snmp community string. Default public.
#   3: -u | --user: user. -p | --pass: password.
# Example: check_wg_cpu.sh -h 192.168.2.100
# Example: check_wg_cpu.sh -h 192.168.2.100 -c 80 -w 90 -v 2 -s publicwg
# Example: check_wg_cpu.sh -h 192.168.2.100 -c 80 -w 90 -v 3 -u read -p 1234567789
#---------------------------------------------------
# Reference https://techsearch.watchguard.com/KB/?type=KBArticle&SFDCID=kA22A000000HQ0PSAW&lang=en_US
#---------------------------------------------------

# Default variables
warning=90
critical=100
version="2"
community="public"
timeout="10"
oid="1.3.6.1.4.1.2021.11.11.0"

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
    --help)
      echo "Usage: check_wg_cpu.sh [options]"
      echo "   -h | --host: ip of device. Ex: 192.168.2.100"
      echo "   -w | --warning: % of cpu warning. Default 90"
      echo "   -c | --critical: % of cpu critical. Defaul 100"
      echo "   -v | --version: snmp version. Default 2. Depends on version you must specify:"
      echo "       2: -s | --string: snmp community string. Default public"
      echo "       3: -u | --user: user. -p | --pass: password"
      echo "Example: check_wg_cpu.sh -h 192.168.2.100"
      echo "Example: check_wg_cpu.sh -h 192.168.2.100 -c 80 -w 90 -v 2 -s publicwg"
      echo "Example: check_wg_cpu.sh -h 192.168.2.100 -c 80 -w 90 -v 3 -u read -p 1234567789"
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

# Run SNMP Command
cpu=`snmpget $args $host $oid 2> /dev/null| cut -d = -f2 | cut -d " " -f2`
if [[ -z $cpu ]]
then 
    echo "Unknown: cpu stats not found"
    exit 3
fi
cpu=`echo "100 - $cpu" | bc -l`
output="CPU usage: $cpu%"
perf="| cpu=$cpu%;$warning;$critical;0;100"

# Check SNMP command result
if [[ "$cpu" -gt "$critical" ]]
then
    echo "Critical. $output $perf"
    exit 2
fi
if [[ "$cpu" -gt "$warning" ]] 
then
    echo "Warning. $output $perf"
    exit 1
fi
echo "Ok. $output $perf"
exit 0