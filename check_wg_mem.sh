#!/bin/bash
# check_wg_memory for Nagios
# Version: 1.0
# March 2022 - Juan Granados
#---------------------------------------------------
# This plugin checks memory usage of Watchguard device and returns memory performance data
# Usage: check_wg_mem.sh [options]
# -h | --host: ip of device.
# -w | --warning: % of memory warning. Default 85.
# -c | --critical: % of memory critical. Default 95.
# -v | --version: snmp version. Default 2. Depends on version you must specify:
#   2: -s | --string: snmp community string. Default public.
#   3: -u | --user: user. -p | --pass: password.
# Example: check_wg_mem.sh -h 192.168.2.100
# Example: check_wg_mem.sh -h 192.168.2.100 -c 80 -w 90 -v 2 -s publicwg
# Example: check_wg_mem.sh -h 192.168.2.100 -c 80 -w 90 -v 3 -u read -p 1234567789
#---------------------------------------------------
# Reference https://techsearch.watchguard.com/KB/?type=KBArticle&SFDCID=kA22A000000HQ0PSAW&lang=en_US
#---------------------------------------------------

# Default variables
warning=85
critical=95
version="2"
community="public"
timeout="10"
oid_total_mem="1.3.6.1.4.1.2021.4.5.0"
oid_free_mem="1.3.6.1.4.1.2021.4.11.0"
oid_total_swap="1.3.6.1.4.1.2021.4.3.0"
oid_used_swap="	1.3.6.1.4.1.2021.4.4.0"

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
      echo "   -w | --warning: % of cpu warning. Default 85"
      echo "   -c | --critical: % of cpu critical. Defaul 95"
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
snmp_mem=`snmpget $args $host $oid_total_mem $oid_free_mem $oid_total_swap $oid_used_swap 2> /dev/null`
if [[ -z $snmp_mem ]]
then 
    echo "Unknown: memory stats not found"
    exit 3
fi
total_mem=`echo $snmp_mem | cut -d = -f2 | cut -d " " -f2`
free_mem=`echo $snmp_mem | cut -d = -f3 | cut -d " " -f2`
total_swap=`echo $snmp_mem | cut -d = -f4 | cut -d " " -f2`
free_swap=`echo $snmp_mem | cut -d = -f5 | cut -d " " -f2`
percent_used_mem=`echo "100 - (($free_mem * 100) / $total_mem)" | bc -l | cut -d. -f1`
if [[ total_swap -gt 0 ]]
then
  percent_used_swap=`echo "100 - (($free_swap * 100) / $total_swap)" | bc -l | cut -d. -f1`
else
  percent_used_swap=0
fi
used_mem=`echo "$total_mem - $free_mem" | bc -l`
used_mem_warning=`echo "($total_mem * $warning) / 100" | bc -l | cut -d. -f1`
used_mem_critical=`echo "($total_mem * $critical) / 100" | bc -l | cut -d. -f1`
free_mem_warning=`echo "$total_mem - $used_mem_warning" | bc -l | cut -d. -f1`
free_mem_critical=`echo "$total_mem - $used_mem_critical" | bc -l | cut -d. -f1`
used_swap=`echo "$total_swap - $free_swap" | bc -l`
output="Memory usage: $percent_used_mem%"
perf="| %mem_used=$percent_used_mem%;$warning;$critical;0;100 %swap_used=$percent_used_swap%;;;0;100 mem_used=$(echo $used_mem)KB;$used_mem_warning;$used_mem_critical;0;$total_mem mem_free=$(echo $free_mem)KB;$free_mem_warning;$free_mem_critical;0;$total_mem swap_used=$(echo $used_swap)KB;;;0;$total_swap swap_free=$(echo $free_swap)KB;;;0;$total_swap"

# Check SNMP command result
if [[ "$percent_used_mem" -gt "$critical" ]]
then
    echo "Critical. $output $perf"
    exit 2
fi
if [[ "$percent_used_mem" -gt "$warning" ]] 
then
    echo "Warning. $output $perf"
    exit 1
fi
echo "Ok. $output $perf"
exit 0