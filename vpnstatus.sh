#!/bin/bash

#############################################################
#
#           script: vpnstatus.sh
#       written by: Marek Novotny
#          version: 3.0
#             date: Sat Mar 05 07:27PM 2016
#          purpose: test status of live vpn connection
#                 : kill torrent if vpn disconnects
#          licence: GPL v2 (only)
#           github: https://github.com/marek-novotny/vpntools
#            usage: vpnstatus {OpenVPNConfig.ovpn} 
#            notes: this script launches vpn and tests its
#                 : connection on-going. If the connection
#                 : terminates then vpn apps are terminated
#                 : as a safety...
#                 : also prevents non-vpn from running under
#                 : vpn. 
#
#############################################################

clear

# apps allowed to run under vpn. These terminate if vpn fails...
vpnApps=(transmission)

# apps not allowed to run when vpn is up. 
# If launched or running these will terminate when the vpn is up. 
nonVpnApps=(thunderbird)

appName="$(basename $0)"

sendMessage () {
	if [ $1 -ge 1 ] ; then
		echo "$2" >&2 && exit $1
	else
		echo "$2"
	fi
}

if [ $# -ne 1 -o "${1##*.}" != "ovpn" ] ; then
	sendMessage 1 "$appName Usage Error: $appName {vpn_config_file.ovpn}"
	else
		configFile="$1"
		if [ -r "$configFile" ] ; then
			sendMessage 0 "$appName Status: $configFile accepted!"
		else
			sendMessage 1 "$appName Error: Config file $configFile cannot be read."
		fi
fi

# can add more apps after openvpn to check for multiple dependencies...

for x in openvpn ; do
	which $x &> /dev/null
	if [ $? -ne 0 ] ; then
		sendMessage 1 "$appName Status: Dependency $x not found..."
	fi
done

# check user credentials to create a vpn tunnel. 

if [ $(id -u) -ne 0 ] ; then
	priv="sudo"
	sendMessage 0 "$appName Status: sudo validation."
	$priv -v
	if [ $? -ne 0 ] ; then
		sendMessage 1 "$appName Status: validation failed..."
	fi
	else
	priv=""
fi

getConnected () {
	
	# report existing default device ID
	sendMessage 0 "$appName Status: Obtaining Device ID "
	devID=$(ip route get 8.8.8.8 | awk '{print $5}')
	sendMessage 0 "$appName Status: Device ID Set: ${devID}."
	
	# set temp vpnID to match existing device ID
	vpnID=$devID
	sendMessage 0 "$appName Status: Obtaining VPN Connection "
	$priv openvpn --config $configFile &> /dev/null &
	ovpnPID=$!
	sendMessage 0 "$appName Status: OpenVPN Process ID: ${ovpnPID}."
	
	# attempt to connect to VPN and change temp vpn ID to assigned tunnel ID
	let count=0
	while [[ $vpnID == $devID ]] ; do
		printf "%s" "#"
		sleep 1
		((count++))
		vpnID=$(ip route get 8.8.8.8 | awk '{print $5}')
		if [ $count -ge 25 ] ; then
			$priv kill $ovpnPID
			echo
			sendMessage 1 "$appName Error: $configFile hung."
		fi
	done
	echo
	sendMessage 0 "$appName Status: Obtained VPN: ${vpnID}."
}

vpnStatus () {
	
	# set conditions for what happens when the vpn is up.
	
	while [[ "$vpnID" != "$devID" ]] ; do
		vpnID=$(ip route get 8.8.8.8 | awk '{print $5}')
		
		# kill apps that should not be running when VPN is up. 
		for x in "${nonVpnApps[@]}" ; do
		pgrep "$x" &> /dev/null
		if [ $? -ne 1 ] ; then
			sendMessage 0 "$appName Status: Task $x is running..."
			pkill -9 "$x"
			if [ $? -eq 0 ] ; then
			sendMessage 0 "$appName Status: Task $x has been terminated."
			fi
		fi
		done
	done

	sendMessage 0 "$appName Status: VPN Failed!"
	
	# Kill apps that should not be running when VPN is down.
	for x in "${vpnApps[@]}" ; do
		pgrep "$x" &> /dev/null
		if [ $? -ne 1 ] ; then
			sendMessage 0 "$appName Status: Task $x is running..."
			pkill -9 "$x" &> /dev/null
			if [ $? -eq 0 ] ; then
			sendMessage 0 "$appName Status: Task $x has been terminated."
			fi
		fi
	done
	
	# after failure, clean up session if remaining. 
	
	if [[ $(kill -0 $ovpnPID &> /dev/null) -eq 0 ]] ; then
		sendMessage 0 "$appName Status: Terminating openVPN session."
		$priv kill $ovpnPID
		if [ $? -eq 0 ] ; then
			sendMessage 0 "$appName Status: OpenVPN session terminated."
			devID=$(ip route get 8.8.8.8 | awk '{print $5}')
			sendMessage 0 "$appName Status: Default device = $devID"
		fi
		
		else
			sendMessage 0 "$appName Status: OpenVPN session has closed."
			devID=$(ip route get 8.8.8.8 | awk '{print $5}')
			sendMessage 0 "$appName Status: Default device = $devID"
	fi
			
}

getConnected
vpnStatus

## END ##
