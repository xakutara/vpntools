#!/bin/bash

############################################################
#                                                                                             
#                script: kickorkeep
#               version: .01
#                  date: 2016-02-22
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

ovpnTest () {
	
	let count=6
	echo
	echo "$(basename $0) message: testing $x"
	echo 
	echo "$(basename $0) message: obtaining device id... "
	devID=$(ip route get 8.8.8.8 | awk '{print $5}')
	echo "$(basename $0) message: device id set: ${devID}..."
	vpnID=$devID
	printf "%s" "$(basename $0) message: obtaining vpn connection..."
	$priv openvpn --config $x &> /dev/null &
	while [[ $vpnID == $devID ]] ; do
		sleep 5
		((count--))
		printf "%s" "${count}."
		vpnID=$(ip route get 8.8.8.8 | awk '{print $5}')
		if [ $count -le 1 ] ; then
			$priv pkill openvpn
			printf "\n%s\n" "$(basename $0) error: $(basename $x) hung..."
			echo "$(basename $0) message: putting this file in the loser bin..."
			return 1
		fi
	done
	printf "\n%s\n" "$(basename $0) message: obtained vpn: ${vpnID}..."
	echo "$(basename $0) message: successful connect..."
	echo "$(basename $0) message: putting this file in the winner bin..."
	$priv pkill openvpn
	sleep 3
	return 0
}

if [ $# -ne 0 ] ; then
	echo "$(basename $0) error: just run this without arguments)"
	echo "from within a directory full of .ovpn config files..."
	exit 1
fi

if [ $(id -u) -ne 0 ] ; then
	priv=sudo
	$priv -v
else
	priv=""
fi

if [ ! -d ~/kickorkeep/winners -o ! -d ~/kickorkeep/losers ] ; then
	mkdir -p ~/kickorkeep/winners
	mkdir -p ~/kickorkeep/losers
fi

IFS=$'\n'
array=( $(find . -maxdepth 1 -type f -name "*.ovpn") )
if [ "${#array[@]}" -ge 1 ] ; then
	for x in "${array[@]}" ; do
		ovpnTest
		if [ $? -eq 0 ] ; then
			mv $x ~/kickorkeep/winners/
		else
			mv $x ~/kickorkeep/losers/
		fi
	done
else
	echo "$(basename $0) message: no ovpn files found here..."
	echo "$(basename $0) message: exiting..."
fi

## END ##
