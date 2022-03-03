#!/bin/bash
# check_wg_load for Nagios
# Version: 0.1
# March 2022 - Juan Granados
#---------------------------------------------------
# This plugin checks CPU load of Watchguard device and returns load performance data
# Usage: check_wg_load.sh [options]
# -h | --host: ip of device.
# -w1 | --warning1: load1 warning. Default: 0.7
# -c1 | --critical1: load1 critical. Default: 1.
# -w5 | --warning5: load5 warning. Default: 0.7
# -c5 | --critical5: load5 critical. Default: 1.
# -w15 | --warning15: load15 warning. Default: 0.7
# -c15 | --critical15: load15 critical. Default: 1.
# -a | --auto: auto detects number of cores and multiply warning and critical by cores.
#              Ex. warning=0.7 and critical=1 will be w=2.8 and c=4 on a device with 4 cores.
# -v | --version: snmp version. Depends of version you must specify.
#   2: -s | --string: snmp community string.
#   3: -u | --user: user. -p | --pass: password.
# Example: check_wg_load.sh -h 192.168.2.100 -a
# Example: check_wg_load.sh -h 192.168.2.100 -c1 1 -w1 0.7 -w5 0.5 -c5 0.8 -w15 0.5 -c15 0.6 -v 2 -s publicwg -a
# Example: check_wg_load.sh -h 192.168.2.100 -c1 2 -w1 0.8 -v 3 -u read -p 1234567789 -a
#---------------------------------------------------
# Reference https://techsearch.watchguard.com/KB/?type=KBArticle&SFDCID=kA22A000000HQ0PSAW&lang=en_US
#---------------------------------------------------

# Default variables
warning1=0.7
critical1=1
warning5=0.7
critical5=1
warning15=0.7
critical15=1
version="2"
community="public"
timeout="10"
host=""
auto=0
oid_num_cpu="1.3.6.1.2.1.25.3.3.1.2"
oid_load1="1.3.6.1.4.1.2021.10.1.3.1"
oid_load5="1.3.6.1.4.1.2021.10.1.3.2"
oid_load15="1.3.6.1.4.1.2021.10.1.3.3"

# Process arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --warning1*|-w1*)
      if [[ "$1" != *=* ]]; then shift; fi
      warning1="${1#*=}"
      ;;
    --critical1*|-c*)
      if [[ "$1" != *=* ]]; then shift; fi
      critical1="${1#*=}"
      ;;
      --warning5*|-w*)
      if [[ "$1" != *=* ]]; then shift; fi
      warning5="${1#*=}"
      ;;
    --critical5*|-c*)
      if [[ "$1" != *=* ]]; then shift; fi
      critical5="${1#*=}"
      ;;
    --warning15*|-w*)
      if [[ "$1" != *=* ]]; then shift; fi
      warning15="${1#*=}"
      ;;
    --critical15*|-c*)
      if [[ "$1" != *=* ]]; then shift; fi
      critical15="${1#*=}"
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
      --auto*|-a*)
      auto=1
      ;;
    --help)
      echo "Usage: check-wg_cpu.sh [options]"
      echo "   -h | --host: ip of device. Ex: 192.168.2.100"
      echo "   -w1 | --warning1: load1 warning. Default: 0.7"
      echo "   -c1 | --critical: load1 critical. Default 1"
      echo "   -w5 | --warning5: load5 warning. Default: 0.7"
      echo "   -c5 | --critica5: load5 critical. Default 1"
      echo "   -w15 | --warning15: load15 warning. Default: 0.7"
      echo "   -c15 | --critical5: load15 critical. Default 1"
      echo "   -a | --auto: auto detects number of cores and multiply warning and critical by cores."
      echo "                Ex. warning=0.7 and critical=1 will be w=2.8 and c=4 on a device with 4 cores"
      echo "   -v | --version: snmp version. Depends of version you must specify. Default 2"
      echo "       2: -s | --string: snmp community string. Default public"
      echo "       3: -u | --user: user. -p | --pass: password"
      echo "Example: check_wg_load.sh -h 192.168.2.100 -a"
      echo "Example: check_wg_load.sh -h 192.168.2.100 -c1 1 -w1 0.7 -w5 0.5 -c5 0.8 -w15 0.5 -c15 0.6 -v 2 -s publicwg -a"
      echo "Example: check_wg_load.sh -h 192.168.2.100 -c1 2 -w1 0.8 -v 3 -u read -p 1234567789 -a"
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
if [[ $(echo $warning1'>'$critical1 | bc -l) -eq 1 ]]
then
    echo "Unknown: Critical1 must be higher than warning1"
    exit 3
fi
if [[ $(echo $warning5'>'$critical5 | bc -l) -eq 1 ]]
then
    echo "Unknown: Critical5 must be higher than warning5"
    exit 3
fi
if [[ $(echo $warning15'>'$critical15 | bc -l) -eq 1 ]]
then
    echo "Unknown: Critical15 must be higher than warning15"
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
cpu=`snmpget $args $host $oid_load1 $oid_load5 $oid_load15 2> /dev/null`
if [[ -z $cpu ]]
then 
  echo "Unknown: cpu stats not found"
  exit 3
fi
# If auto, update warning and critical
if [[ $auto -eq 1 ]]
then
  num_cores=`snmpwalk $args $host 1.3.6.1.2.1.25.3.3.1.2 | wc -l`
  if [[ -z $num_cores ]]
  then 
    echo "Unknown: number of cores not found"
    exit 3
  fi
  warning1=`echo "$num_cores * $warning1" | bc -l`
  critical1=`echo "$num_cores * $critical1" | bc -l`
  warning5=`echo "$num_cores * $warning5" | bc -l`
  critical5=`echo "$num_cores * $critical5" | bc -l`
  warning15=`echo "$num_cores * $warning15" | bc -l`
  critical15=`echo "$num_cores * $critical15" | bc -l`
fi
load1=`echo $cpu | cut -d \" -f2`
load5=`echo $cpu | cut -d \" -f4`
load15=`echo $cpu | cut -d \" -f6`
output="CPU load average: $load1, $load5, $load15 "
perf="| load1=$load1;$warning1;$critical1;; load5=$load5;$warning5;$critical5;; load15=$load15;$warning15;$critical15;;"

# Check SNMP command result
if [[ $(echo $load1'>'$critical1 | bc -l) -eq 1 || $(echo $load5'>'$critical5 | bc -l) -eq 1 || $(echo $load15'>'$critical15 | bc -l) -eq 1 ]]
then
    echo "Critical. $output $perf"
    exit 2
fi
if [[ $(echo $load1'>'$warning1 | bc -l) -eq 1 || $(echo $load5'>'$warning5 | bc -l) -eq 1 || $(echo $load15'>'$warning15 | bc -l) -eq 1 ]]
then
    echo "Warning. $output $perf"
    exit 1
fi
echo "Ok. $output $perf"
exit 0