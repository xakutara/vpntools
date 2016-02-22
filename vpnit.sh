#!/bin/bash

#########################################################
#
#                 script: vpnTS
#               version: .01
#                  date: 2016-02-21
#            written by: marek novotny
#                   git:
#               license:
#          dependencies: python, ip, openvpn, whois
#                 notes: 
#
#########################################################

geoDat="/usr/share/GeoIP/GeoLiteCity.dat"

privCheck () {
	if [ $(id -u) -ne 0 ] ; then
		priv=sudo
	else
		priv=""
	fi
}

depCheck () {
	if [ ! -d /usr/share/GeoIP -o ! -r "$geoDat" ] ; then
		echo "$(basename $0) Message: Downloading GeoLiteCity.dat"
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

	deps=(wget python ip openvpn whois geoiplookup speedtest-cli)
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

dateStamp=$(date +%Y_%m_%d)
ip_address=$(wget -4 -qO- icanhazip.com)

geoData () {
	IFS=$','
	set -- $(geoiplookup -f "$geoDat" $ip_address)
	country="${2/ Rev 1: /}"
	state_abv="$3"
	state_long="$4"
	city="$5"
	zip="$6"
	IFS=$'\t\n '
}

geoData

speedData () {
	set -- $(speedtest-cli --simple --timeout 5)
	pingResult=${1/[Aa-Zz]: /}
	downloadResult=${2/[Aa-Zz]: /}
	uploadResult=${3/[Aa-Zz]: /}
}

speedData

echo $pingResult
