#!/bin/bash
# check_wg_tunnels for Nagios
# Version: 1.0
# March 2022 - Juan Granados
#---------------------------------------------------
# This plugin checks if one or more of IPSec tunnels are active on a Watchguard device.
# Usage: check_wg_tunnels.sh [options]
# -h | --host: ip of device.
# -t | --tunnels: list of tunnels to check. 
#                 Syntax "localIP1-PeerIP1 localIP2-PeerIP2 localIPn-PeerIPn"
#                 Example: "80.24.56.73-90.123.124.34 100.234.45.47-90.12.45.123 123.234.43.65-65.234.56.78"
# -v | --version: snmp version. Default 2. Depends on version you must specify:
#   2: -s | --string: snmp community string. Default public.
#   3: -u | --user: user. -p | --pass: password.
# Example: check_wg_tunnels.sh -h 192.168.2.100 -s publicsnmp -t "80.24.56.73-90.123.124.34 100.234.45.47-90.12.45.123"
# Example: check_wg_tunnels.sh -h 192.168.2.100 -v 3 -u read -p 1234567789 -t "80.24.56.73-90.123.124.34 100.234.45.47-90.12.45.123 123.234.43.65-65.234.56.78"
#---------------------------------------------------
# Reference https://www.watchguard.com/help/docs/help-center/en-US/Content/en-US/Fireware/basicadmin/snmp_mibs_details_c.html
#---------------------------------------------------

# Default variables
version="2"
community="public"
timeout="10"
wgIpsecEndpointPairLocalAddr="1.3.6.1.4.1.3097.5.1.1.2.1.2"
wgIpsecEndpointPairPeerAddr="1.3.6.1.4.1.3097.5.1.1.2.1.3"
exitCode=0
output=""

# Process arguments
while [ $# -gt 0 ]; do
  case "$1" in
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
      tunnels--*|-t*)
      if [[ "$1" != *=* ]]; then shift; fi
      tunnels="${1#*=}"
      ;;
    --help)
      echo "Usage: check_wg_tunnels.sh [options]"
      echo "   -h | --host: ip of device. Ex: 192.168.2.100"
      echo "   -v | --version: snmp version. Default 2. Depends on version you must specify:"
      echo "       2: -s | --string: snmp community string. Default public"
      echo "       3: -u | --user: user. -p | --pass: password"
      echo "   -t | --tunnels: list of tunnels to check"
      echo "                   Syntax \"localIP1-PeerIP1 localIP2-PeerIP2 localIPn-PeerIPn\""
      echo "                   Example: \"80.24.56.73-90.123.124.34 100.234.45.47-90.12.45.123 123.234.43.65-65.234.56.78\""
      echo "Example: check_wg_tunnels.sh -h 192.168.2.100 -s publicsnmp -t \"80.24.56.73-90.123.124.34 100.234.45.47-90.12.45.123\""
      echo "Example: check_wg_tunnels.sh -h 192.168.2.100 -v 3 -u read -p 1234567789 -t \"80.24.56.73-90.123.124.34 100.234.45.47-90.12.45.123 123.234.43.65-65.234.56.78\""
      exit 3
      ;;
    *)
      >&2 printf "Error: Invalid argument: $1\n"
      exit 3
      ;;
  esac
  shift
done

# https://stackoverflow.com/a/13778973
ipvalid() {
  # Set up local variables
  local ip=${1:-1.2.3.4}
  local IFS=.; local -a a=($ip)
  # Start with a regex format test
  [[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  # Test values of quads
  local quad
  for quad in {0..3}; do
    [[ "${a[$quad]}" -gt 255 ]] && return 1
  done
  return 0
}

# Check arguments
if ! [[ $(command -v snmpwalk) ]]
then
    echo "snmpwalk could not be found. Please install it and try again"
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
if [[ -z $tunnels ]]
then
    echo "Unknown: tunnels can not be empty"
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

# Get tunnels info
localAddr=( $( snmpwalk $args $host $wgIpsecEndpointPairLocalAddr  | cut -d "=" -f2 | cut -d " " -f2 ) )
peerAddr=( $( snmpwalk $args $host $wgIpsecEndpointPairPeerAddr  | cut -d "=" -f2 | cut -d " " -f2 ) )
tunnels=( $( echo $tunnels ) )

# Check tunnels
for t in "${tunnels[@]}"
do
   up=0
   local=`echo "$t"  | cut -d "-" -f1`
   peer=`echo "$t"  | cut -d "-" -f2`
   if ! [[ `echo "$t"  | grep -` ]]
   then
    echo "Unknown: bad 't' parameter. Syntax \"localIP1-PeerIP2 localIP1-PeerIP2 localIPn-PeerIPn\""
    exit 3
   fi
   if [[ $local = $peer ]]
   then
    echo "Unknown: local IP and peer IP can not be the same. Syntax \"localIP1-PeerIP2 localIP1-PeerIP2 localIPn-PeerIPn\""
    exit 3
   fi
   if ! ipvalid "$local"
   then
    echo "Unknown: $local is not a valid IP"
    exit 3
   fi
   if ! ipvalid "$peer"
   then
    echo "Unknown: $peer is not a valid IP"
    exit 3
   fi
   arraylength=${#localAddr[@]}
   for (( i=0; i<${arraylength}; i++ ));
    do
      if [[ ("${localAddr[$i]}" = "$local") && ("${peerAddr[$i]}" = "$peer") ]]
      then
        up=1
      fi
    done
    if [[ $up -eq 1 ]]
    then
      output="${output:+$output. }$t is up"
    else
    output="${output:+$output. }$t is down"
    exitCode=2
    fi
done

# Exit
if [[ $exitCode -eq 0 ]]
then
  echo "Ok. $output"
  exit 0
else
  echo "Critical. $output"
  exit 2
fi