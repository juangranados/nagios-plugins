#!/bin/bash
warning=1
critical=2
disk=$(mount |grep ' / ' | cut -d' ' -f 1 | cut -d'/' -f 3)
re='^[0-9]+([.][0-9]+)?$'

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
      echo "Usage: check-diskq.sh -d <disk> -c <critical_threshold> -w <warning_threshold>"
      echo "Example: check-diskq.sh -d sdb -c 2 -w 0.5"
      echo "Example: check-diskq.sh --disk sda --critical 1.5 --warning 0.5"
      exit 3
      ;;
    *)
      >&2 printf "Error: Invalid argument\n"
      exit 3
      ;;
  esac
  shift
done


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
eval "$(iostat /dev/$disk -x -o JSON | jq .[].hosts[].statistics[].disk | jq -r '.[] | to_entries | .[] | .key + "=" + (.value | @sh)' | tr -d '/-')"
if [ -z $aqusz ]
then 
    echo "Unknown: disk queue lenght not found"
    exit 3
fi
output="Stats for disk $disk -> Queue:$aqusz Read:${rkBs}kB/s Read/s:$rs Write:${wkBs}kB/s Writes/s:$ws %util:$util%"
perf="| queue=$aqusz;$warning;$critical;; read=${rkBs}KB;;;; reads=$rs;;;; write=${wkBs}KB;;;; writess=$ws;;;; util=$util%;;;;"

if [ $(echo $aqusz'>'$critical | bc -l) -eq 1 ]
then
    echo "Critical. $output $perf"
    exit 2
fi
if [ $(echo $aqusz'>'$warning | bc -l) -eq 1 ] 
then
    echo "Warning. $output $perf"
    exit 1
fi
echo "Ok. $output $perf"
exit 1