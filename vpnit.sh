#!/bin/bash

#########################################################
#
#                 script: vpnit
#               version: .02
#                  date: 2016-02-21
#            written by: marek novotny
#                   git: https://github.com/marek-novotny/vpntools
#               license: GPL v2 (only)
#          dependencies: python, speedtest-cli
#                      : wget, openvpn, ip, geoip-bin
#               purpose: gather geo-ip data and speed
#                      : rename ovpn file accordingly
#                 usage: vpnit path/config.ovpn
#
#########################################################

clear

if [ $# -ne 1 ] ; then
	echo "$(basename $0) usage error:" 
	echo "please use one argument, which shall be an ovpn file to test..."
	exit 1
else
	ovpnFile="$1"
fi

privCheck () {
	
	if [ $(id -u) -ne 0 ] ; then
		priv=sudo
	else
		priv=""
	fi
}

depCheck () {
	
	geoDat="/usr/share/GeoIP/GeoLiteCity.dat"
	if [ ! -d /usr/share/GeoIP -o ! -r "$geoDat" ] ; then
		echo "$(basename $0) Message: downloading GeoLiteCity.dat"
		cd ~/
		wget -q http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
		if [ $? -eq 0 ] ; then
			gunzip GeoLiteCity.dat.gz && \
				$priv mkdir -p /usr/share/GeoIP && \
				$priv mv GeoLiteCity.dat /usr/share/GeoIP/
		else
			echo "$(basename $0) download failure..."
			echo "unable to download GeoLiteCity.dat..."
			exit 1
		fi
	fi

	if [ ! -f /usr/local/bin/speedtest-cli ] ; then
		echo "$(basename $0) message: downloading speedtest-cli..."
		$priv wget -q -O /usr/local/bin/speedtest-cli \
			https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest_cli.py
		if [ $? -eq 0 ] ; then
			$priv chmod +x /usr/local/bin/speedtest-cli
		fi
	fi

	deps=(wget python ip openvpn geoiplookup speedtest-cli)
	
	for x in ${deps[@]} ; do
		which $x &> /dev/null
		if [ $? -ne 0 ] ; then
			depsMissing+=( $x )
		fi
	done

	if [ ${#depsMissing[@]} -ge 1 ] ; then
		echo "$(basename $0) dependency requirement failure..."
		echo "required: ${depsMissing[@]}"
		exit 1
	fi
}

privCheck
depCheck

if [ ! -r "$ovpnFile" ] ; then
	echo "$(basename $0) error: cannot read ${ovpnFile}..."
	exit 1
fi

getConnected () {
	
	let count=6
	echo "$(basename $0) message: obtaining device id... "
	devID=$(ip route get 8.8.8.8 | awk '{print $5}')
	echo "$(basename $0) message: device id set: ${devID}..."
	vpnID=$devID
	printf "%s" "$(basename $0) message: obtaining vpn connection..."
	$priv openvpn --config $ovpnFile &> /dev/null &
	while [[ $vpnID == $devID ]] ; do
		sleep 5
		((count--))
		printf "%s" "${count}."
		vpnID=$(ip route get 8.8.8.8 | awk '{print $5}')
		if [ $count -le 1 ] ; then
			$priv pkill openvpn
			printf "\n%s\n" "$(basename $0) error: $(basename $ovpnFile) hung..."
			echo "$(basename $0) message: exiting..."
			exit 1
		fi
	done
	printf "\n%s\n" "$(basename $0) message: obtained vpn: ${vpnID}..."
	return 0
}

geoData () {
	
	echo "$(basename $0) message: collecting geo-data..."
	IFS=$','
	set -- $(geoiplookup -f "$geoDat" $ip_address)
	country="${2/*: /}"
	state_abv="${3/' N/A'/na}"
	state_long="${4/' N/A'/na}"
	city="${5/' N/A'/na}"
	zip="${6/' N/A'/na}"
	IFS=$'\t\n '
}

speedData () {
	
	echo "$(basename $0) message: collecting speed test data..."
	IFS=$'\n'
	set -- $(speedtest-cli --simple --secure --timeout 5)
	pingResult="${1/*: /}"
	downResult="${2/*: /}"
	upResult="${3/*: /}"
	IFS=$'\t\n '
}

getConnected

if [ $? -eq 0 ] ; then
	dateStamp=$(date +%Y_%m_%d)
	ip_address=$(wget -4 -qO- icanhazip.com)
	geoData
	speedData
fi

cat << EOF

Filename Prefix: $(basename ${ovpnFile/_*/})
Country: $country
State: $state_abv
City: $city
IP: $ip_address
PING: $pingResult
Upload Speed: $upResult
Download Speed: $downResult

EOF

$priv pkill openvpn

renameSource () {

	filePath=$(dirname $ovpnFile)
	
	prefx=$(basename ${ovpnFile/_*/})
	pingR=${pingResult/.*/}
	upR=${upResult/'it/s'/}
	downR=${downResult/'it/s'/}
	
	tmpName="${prefx}_cntry_${country,,}_ping_${pingR}_dwn_${downR}_up_${upR}.ovpn"
	newName="$(echo $tmpName | tr ' ' '_')"
	
	mv $ovpnFile "$filePath/$newName"

	if [ $? -eq 0 ] ; then
		echo "$(basename $0) message: file renamed..."
		echo "file = $newName"
	else
		echo "$(basename $0) error: unable to rename existing file..."
		echo "file = $ovpnFile"
	fi
}

renameSource

## END ##
