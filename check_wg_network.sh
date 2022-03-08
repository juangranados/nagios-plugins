#!/bin/bash
# check_wg_network for Nagios
# Version: 0.4
# March 2022 - Juan Granados
#---------------------------------------------------
# This plugin checks network usage of Watchguard device and returns network performance data.
# Usage: check_wg_network.sh [options]
# -h | --host: ip of device.
# -w | --warning: optional. Number of connections warning.
# -c | --critical: optional. Number of connections critical.
# -iw | --iwarning: optional. % of usage of interface warning.
# -ic | --icritical: optional. % of usage of interface critical.
# -v | --version: snmp version. Default 2. Depends on version you must specify:
#   2: -s | --string: snmp community string. Default public.
#   3: -u | --user: user. -p | --pass: password.
# -i | --interfaces: list of interfaces to monitor. Default all (autodetects interfaces). Ex: "eth0 eth1 eth2 eth3"
# -t | --time: polling time in seconds. Default 10.
# -d | --dspeed: default speed of interfaces in case that snmp returns 0. Default 1000000000.
# Example: check_wg_network.sh -h 192.168.2.100 -c 800000 -w 900000 -v 2 -s publicwg -i "eth0 eth1 vlan1"
# Example: check_wg_network.sh -h 192.168.2.100 -c 800000 -w 900000 -v 3 -u read -p 1234567789 -t 15
# https://networkengineering.stackexchange.com/questions/57435/network-bandwidth-utilization-with-snmp
# https://serverfault.com/questions/401162/how-to-get-interface-traffic-snmp-information-for-routers-cisco-zte-huawei
#---------------------------------------------------
# Reference https://techsearch.watchguard.com/KB/?type=KBArticle&SFDCID=kA22A000000HQ0PSAW&lang=en_US
#---------------------------------------------------

# Default variables
version="2"
community="public"
timeout=10
conn_oid="1.3.6.1.4.1.3097.6.3.80"
ifName="1.3.6.1.2.1.31.1.1.1.1"
ifSpeed="1.3.6.1.2.1.2.2.1.5"
ifHighSpeed="1.3.6.1.2.1.31.1.1.1.15"
ifHCInOctets="1.3.6.1.2.1.31.1.1.1.6"
ifHCOutOctets="1.3.6.1.2.1.2.2.1.16"
interfaces="all"
polling=10
dspeed=1000000000
warning=2147483647
critical=2147483647
iwarning=101
icritical=101
exitCode=0
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
    --iwarning*|-iw*)
      if [[ "$1" != *=* ]]; then shift; fi
      iwarning="${1#*=}"
      ;;
    --icritical*|-ic*)
      if [[ "$1" != *=* ]]; then shift; fi
      icritical="${1#*=}"
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
    --interfaces*|-i*)
      if [[ "$1" != *=* ]]; then shift; fi
      interfaces="${1#*=}"
      ;;
    --time*|-t*)
      if [[ "$1" != *=* ]]; then shift; fi
      polling="${1#*=}"
      ;;
    --dspeed*|-d*)
      if [[ "$1" != *=* ]]; then shift; fi
      dspeed="${1#*=}"
      ;;
    --help)
      echo "Usage: check_wg_network.sh [options]"
      echo "   -h | --host: ip of device. Ex: 192.168.2.100"
      echo "   -w | --warning: Optional. Number of connections warning."
      echo "   -c | --critical: Optional. Number of connections critical."
      echo "   -iw | --iwarning: Optional. % of usage of interface warning."
      echo "   -ic | --icritical: Optional. % of usage of interface critical."
      echo "   -v | --version: snmp version. Default 2. Depends on version you must specify:"
      echo "       2: -s | --string: snmp community string. Default public"
      echo "       3: -u | --user: user. -p | --pass: password"
      echo "   -i | --interfaces: list of interfaces to monitor. Default all (autodetects interfaces). Ex: 'eth0 eth1 eth2 eth3'"
      echo "   -t | --time: polling time in seconds. Default 10."
      echo "   -d | --dspeed: default speed of interfaces in case that snmp returns 0. Default 1000000000."
      echo "Example: check_wg_cpu.sh -h 192.168.2.100 -c 80000 -w 90000 -v 2 -s publicwg -i 'eth0 vlan1 eth3'"
      echo "Example: check_wg_cpu.sh -h 192.168.2.100 -c 80000 -w 90000 -v 3 -u read -p 1234567789 -t 15"
      exit 3
      ;;
    *)
      >&2 printf "Error: Invalid argument: $1\n"
      exit 3
      ;;
  esac
  shift
done
function getInterfaceStats {
  if [[ -z $1  ]]
  then
    echo "Unknown: interface cannot be null"
    exit 3
  fi

  ifindex=`snmpwalk $args $host $ifName | grep -w $1 | grep -o "\.[0-9]*\ "`
  if [[ -z $ifindex  ]]
  then
    echo "Unknown: could not get stats for interface $(echo $1)"
    exit 3
  fi

  mbconversion=1000000 # 1000000 bits is 1 Megabite.
  ifspeed=`snmpwalk $args $host $ifSpeed | grep $ifindex | cut -d = -f2 | cut -d " " -f2`
  ifHspeed=`snmpwalk $args $host $ifHighSpeed | grep $ifindex | cut -d = -f2 | cut -d " " -f2`
  if [[ $ifspeed -eq "0" ]]
  then
    ifspeed=$dspeed
    ifHspeed=`echo "$dspeed/$mbconversion" | bc` 
  fi

  result1In=`echo "$ifHCInOctets1" | grep $ifindex | cut -d = -f2 | cut -d " " -f2`
  result2In=`echo "$ifHCInOctets2" | grep $ifindex | cut -d = -f2 | cut -d " " -f2`
  calcIn=`echo "($result2In-$result1In)*8"| bc` # Multiply by 8 to convert octets into bits -> bites received in interval.
  bandwidthIn=`echo "scale=3; x=($calcIn/$polling)/$mbconversion; if(x<1 && x!=0) print 0; x" | bc` # Bits / seconds / Mbites -> Mbps
  percIn=`echo "scale=2; x=(($calcIn/$polling)*100)/$ifspeed; if(x<1 && x!=0) print 0; x" | bc`
  if [[ $(echo $percIn'<'$iwarning | bc -l) -eq 0 && "$exitCode" -eq "0" ]]
  then
    exitCode=1
  elif [[ $(echo $percIn'<'$icritical | bc -l) -eq 0 ]]
  then
    exitCode=2
  fi

  result1Out=`echo "$ifHCOutOctets1" | grep $ifindex | cut -d = -f2 | cut -d " " -f2`
  result2Out=`echo "$ifHCOutOctets2" | grep $ifindex | cut -d = -f2 | cut -d " " -f2`
  calcOut=`echo "($result2Out-$result1Out)*8" | bc` # Multiply by 8 to convert octets into bits -> bites received in interval.
  bandwidthOut=`echo "scale=3; x=($calcOut/$polling)/$mbconversion; if(x<1 && x!=0) print 0; x" | bc` # Bits / seconds / Mbites -> Mbps
  percOut=`echo "scale=2; x=(($calcOut/$polling)*100)/$ifspeed; if(x<1 && x!=0) print 0; x" | bc`
  if [[ $(echo $percOut'<'$iwarning | bc -l) -eq 0 && "$exitCode" -eq "0" ]]
  then
    exitCode=1
  elif [[ $(echo $percOut'<'$icritical | bc -l) -eq 0 ]]
  then
    exitCode=2
  fi
  if [[ "$iwarning" -ne "101" || "$icritical" -ne "101" ]]
  then
    bwarning=`echo "($iwarning*$ifHspeed)/100" | bc`
    bcritical=`echo "($icritical*$ifHspeed)/100" | bc`
    perf="$perf $1_in=$(echo $bandwidthIn)Mb;$bwarning;$bcritical;0;$ifHspeed $1_in%=$(echo $percIn)%;$iwarning;$icritical;0;100 $1_out=$(echo $bandwidthOut)Mb;$bwarning;$bcritical;0;$ifHspeed $1_out%=$(echo $percOut)%;$iwarning;$icritical;0;100"
  else
    perf="$perf $1_in=$(echo $bandwidthIn)Mb;;;0;$ifHspeed $1_in%=$(echo $percIn)%;;;0;100 $1_out=$(echo $bandwidthOut)Mb;;;0;$ifHspeed $1_out%=$(echo $percOut)%;;;0;100"
  fi
  output="$output. $1=IN:$(echo $bandwidthIn)Mb/s OUT:$(echo $bandwidthOut)Mb/s"
} 
# Check arguments
if ! [[ $(command -v snmpwalk) ]]
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
if [[ "$warning" -gt "$critical" ]]
then
  echo "Unknown: warning can not be greater than critical"
  exit 3
fi
if ! [[ $iwarning =~ $re ]]
then
    echo "Unknown: interface warning must be a number"
    exit 3
fi
if ! [[ $icritical =~ $re ]]
then
    echo "Unknown: interface critical must be a number"
    exit 3
fi
if [[ "$iwarning" -gt "$icritical" ]]
then
  echo "Unknown: interface warning can not be greater than interface critical"
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
if ! [[ $polling =~ $re ]]
then
    echo "Unknown: polling must be a number"
    exit 3
fi
if ! [[ $dspeed =~ $re ]]
then
    echo "Unknown: default speed must be a number"
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
conn=`snmpwalk $args $host $conn_oid 2> /dev/null | cut -d = -f2 | cut -d " " -f2`
if [[ -z $conn ]]
then 
    echo "Unknown: connections stats not found"
    exit 3
fi
output="Number of connections: $conn"
if [[ "$warning" -ne "2147483647" || "$critical" -ne "2147483647" ]]
then
  perf="| conn=$conn;$warning;$critical;;"
else
  perf="| conn=$conn;;;;"
fi

# Interfaces stats
ifHCInOctets1=`snmpwalk $args $host $ifHCInOctets`
ifHCOutOctets1=`snmpwalk $args $host $ifHCOutOctets`
sleep $polling
ifHCInOctets2=`snmpwalk $args $host $ifHCInOctets`
ifHCOutOctets2=`snmpwalk $args $host $ifHCOutOctets`
# Gets all interfaces
if [[ "$interfaces" = "all" ]]
then
  interfaces=`snmpwalk $args $host $ifName | sed -r "s/.*?([\"'])(.*)\1.*/\2/"`
fi
IFS=' ' read -r -a array <<< $(echo $interfaces)
for interface in "${array[@]}"
do
  getInterfaceStats "$interface"
done

# Check SNMP command result
if [[ "$conn" -ge "$critical" ]]
then
    exitCode=2
elif [[ "$conn" -ge "$warning" && "$exitCode" -eq "0" ]] 
then
    exitCode=1
fi

if [[ "$exitCode" -eq "0" ]]
then
  echo "Ok. $output $perf"
  exit 0
elif [[ "$exitCode" -eq "1" ]]
then
  echo "Warning. $output $perf"
  exit 1
else
  echo "Critical. $output $perf"
  exit 2
fi