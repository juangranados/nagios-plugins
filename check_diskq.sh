#!/bin/bash
# check_diskq for Nagios
# Version: 0.1
# March 2022 - Juan Granados
#---------------------------------------------------
# This plugin checks disk queue using iostat and returns queue, read/write and active time performance data.
# Usage: check_diskq.sh -d <disk> -w <warning_threshold> -c <critical_threshold> 
# -d | --disk: disk to check queue.
# -w | --warning: queue warning.
# -c | --critical: queue critical.
# -h | --help: shows help.
# Example: check_diskq.sh -d sdb -c 2 -w 0.5
# Example: check_diskq.sh --disk sda --critical 1.5 --warning 0.5
#---------------------------------------------------

# Default variables
warning=1
critical=2
disk=$(mount |grep ' / ' | cut -d' ' -f 1 | cut -d'/' -f 3)
re='^[0-9]+([.][0-9]+)?$'

# Process arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --disk*|-d*)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      disk="${1#*=}"
      ;;
    --warning*|-w*)
      if [[ "$1" != *=* ]]; then shift; fi
      warning="${1#*=}"
      ;;
    -critical*|-c*)
      if [[ "$1" != *=* ]]; then shift; fi
      critical="${1#*=}"
      ;;
    --help|-h)
      echo "Usage: check_diskq.sh -d <disk> -c <critical_threshold> -w <warning_threshold>"
      echo "Example: check_diskq.sh -d sdb -c 2 -w 0.5"
      echo "Example: check_diskq.sh --disk sda --critical 1.5 --warning 0.5"
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
if ! [[ $(command -v iostat) ]]
then
    echo "Unknown: iostat command could not be found. Please install it and try again"
    exit 3
fi
if ! [[ $(command -v jq) ]]
then
    echo "Unknown: jq command could not be found. Please install it and try again"
    exit 3
fi
if ! [[ $(command -v bc) ]]
then
    echo "Unknown: bc command could not be found. Please install it and try again"
    exit 3
fi
if [[ $warning -gt $critical ]]
then
    echo "Unknown: Critical must be higher than warning"
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
if ! [[ $(lsblk | grep $disk) ]]
then
    echo "Unknown: disk not found"
    exit 3
fi

# Get disk queue
eval "$(iostat /dev/$disk -x -o JSON | jq .[].hosts[].statistics[].disk | jq -r '.[] | to_entries | .[] | .key + "=" + (.value | @sh)' | tr -d '/-')"
if [ -z $aqusz ]
then 
    echo "Unknown: disk queue lenght not found"
    exit 3
fi
output="Stats for disk $disk -> Queue:$aqusz Read:${rkBs}kB/s Read/s:$rs Write:${wkBs}kB/s Writes/s:$ws %util:$util%"
perf="| queue=$aqusz;$warning;$critical;; read=${rkBs}KB;;;; reads=$rs;;;; write=${wkBs}KB;;;; writess=$ws;;;; util=$util%;;;;"

# Check disk queue result
if [[ $(echo $aqusz'>'$critical | bc -l) -eq 1 ]]
then
    echo "Critical. $output $perf"
    exit 2
fi
if [[ $(echo $aqusz'>'$warning | bc -l) -eq 1 ]] 
then
    echo "Warning. $output $perf"
    exit 1
fi
echo "Ok. $output $perf"
exit 0
