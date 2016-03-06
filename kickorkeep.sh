#!/bin/bash

############################################################
#                                                                                             
#                script: kickorkeep
#               version: .02
#                  date: 2016-03-05
#            written by: marek novotny
#                   git: https://github.com/marek-novotny/vpntools
#               license: GPL v2 (only)
#          dependencies: wget, openvpn, ip
#               purpose: test ovpn file and keep it or 
#                      : kick it or keep it
#                 usage: execute script from within
#                      : a directory full of ovpn files
#                                                                                             
############################################################

clear
appName="$(basename $0)"

# Message and Error handler

sendMessage () {
	if [ $1 -ge 1 ] ; then
		echo "$2" >&2 && exit $1
	else
		echo "$2"
	fi
}

# check dependencies...

for x in sudo openvpn ; do
	which $x &> /dev/null
	if [ $? -ne 0 ] ; then
		sendMessage 1 "$appName Status: Dependency $x not found..."
	fi
done

# test operator usage
if [ $# -ne 0 ] ; then
	sendMessage 1 "$appName Usage: Run within directory of ovpn files without any arguments."
fi

#t test operator priviledge and set for sudo 
if [ $(id -u) -ne 0 ] ; then
	priv=sudo
	sendMessage 0 "$appName Status: -sudo validation-"
	$priv -v
else
	priv=""
fi

# check for and/or setup directories required for sorting...
if [ ! -d ~/kickorkeep/winners -o ! -d ~/kickorkeep/losers ] ; then
	mkdir -p ~/kickorkeep/winners
	mkdir -p ~/kickorkeep/losers
fi

ovpnTest () {
	
	# set default devID and attempt to connect to VPN
	sendMessage 0 "$appName Status: Testing ${x}."
	devID=$(ip route get 8.8.8.8 | awk '{print $5}')
	sendMessage 0 "$appName Status: Device ID Set: $devID"
	
	# setting vpn ID to temp match devID. Test to see if it changes
	# which indicates that the vpn tunnel has been established...
	vpnID=$devID
	sendMessage 0 "$appName Status: Attempting VPN Connection..."
	$priv openvpn --config $x &> /dev/null &
	ovpnPID=$!
	sendMessage 0 "$appName Status: OpenVPN PID Set - $ovpnPID"
	
	# setup a timer to declare VPN attempt hung if connection passes timed limit...
	echo
	let count=0
	while [[ $vpnID == $devID ]] ; do
		sleep 1
		((count++))
		printf "%s" "#"
		vpnID=$(ip route get 8.8.8.8 | awk '{print $5}')
		if [ $count -ge 25 ] ; then
			echo ; echo
			sendMessage 0 "$appName Status: "$x" hung."
			sendMessage 0 "$appName Status: This file sent to the loser bin."
			echo
			$priv pkill openvpn
			sleep 3
			devID=$(ip route get 8.8.8.8 | awk '{print $5}')
			sendMessage 0 "$appName Status: Connection Reset."
			sendMessage 0 "$appName Status: Default Device ID: $devID"
			return 1
		fi
	done
	
	# Connnection successful, move success ovpn file and reset connection...
	echo ; echo
	sendMessage 0 "$appName Status: VPN obtained: ${vpnID}."
	sendMessage 0 "$appName Status: Successful Connect."
	sendMessage 0 "$appName Status: Placing this file in the winner bin."
	echo
	$priv pkill openvpn
	sleep 3
	devID=$(ip route get 8.8.8.8 | awk '{print $5}')
	sendMessage 0 "$appName Status: Connection Reset."
	sendMessage 0 "$appName Status: Default Device ID: $devID"
	return 0
}

control_c () {

	# kill OpenVPN testing if user terminates with ctrl-c
	
	echo
	sendMessage 0 "$appName Status: BREAK!"
	
	$priv pkill openvpn
	sendMessage 0 "$appName Status: OpenVPN PID: $ovpnPID terminated."
	sleep 3
	devID=$(ip route get 8.8.8.8 | awk '{print $5}')
	sendMessage 0 "$appName Status: Device ID - $devID"
	sendMessage 1 "$appName Status: $appName Terminated."
	
	exit 1
}

trap control_c SIGINT

# build array of ovpn files for testing...

IFS=$'\n'
array=( $(find . -maxdepth 1 -type f -name "*.ovpn") )
if [ "${#array[@]}" -ge 1 ] ; then
	for x in "${array[@]}" ; do
		ovpnTest
		if [ $? -eq 0 ] ; then
			mv "$x" ~/kickorkeep/winners/
		else
			mv "$x" ~/kickorkeep/losers/
		fi
	done
else
	sendMessage 1 "$appName Status: No .ovpn files in the current directory."
fi
IFS=$'\t\n '



## END ##
