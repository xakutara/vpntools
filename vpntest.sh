#!/bin/bash
#################################################
#
#           Script: vpntest.sh
#       written by: Marek Novotny
#          version: 1.2
#             Date: 2015-04-19
#            Notes: Network Testing
#
#################################################

let mtab=22

divider()
{
	printf "%$(tput cols)s\n" "" | tr ' ' '='
}

versionHeader()
{
	version='1.2'
	versionDate='2015-04-19'
	printf "%*s\n" "$(tput cols)" "$(date)"
	printf "%*s\n" "$(tput cols)" "Version $version, released: $versionDate"
}

network()
{
	printf "%s\n" "Network Info"
	divider
	deviceIP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $7}')
	deviceID=$(ip route get 8.8.8.8 | awk 'NR==1 {print $5}')
	printf "%${mtab}s %s %s\n" "Device IP:" "$deviceIP" "($deviceID)"
	defaultRoute=$(route | egrep -i default.*${deviceID} | awk '{print $2}')
	printf "%${mtab}s %s\n" "Default Route:" "$defaultRoute"
	
	if [ $(wget -4 -qO- icanhazip.com) ] ; then 
		externalIP=$(wget -4 -qO- icanhazip.com)
		printf "%${mtab}s %s\n" "External IP:" "$externalIP"
	else
		externalIP="Not Detected"
		printf "%${mtab}s %s\n" "External IP:" "$externalIP"
 		return 1
 		exit 1
	fi
	
	isp=$(wget -4 -qO- ipinfo.io/$externalIP/org)
	country=$(wget -4 -qO- ipinfo.io/$externalIP/country)
	printf "%${mtab}s %s\n" "ISP:" "$isp"
	printf "%${mtab}s %s\n" "Country:" "$country"
	dnsIP=$(dig redhat.com | awk '/SERVER/{print $3}' | awk -F \# '{print $1}')
	dnsName=$(dig +short -x $dnsIP)
	if [ ! $dnsName ]; then
		dnsName="Not Detected"
	fi
 	printf "%${mtab}s %s\n" "DNS IP:" "$dnsIP"
 	printf "%${mtab}s %s\n\n" "DNS Name:" "$dnsName"
}

errorStatus()
{
	errorCon="$?"
	if ((errorCon >= 1)) ; then
		printf "%${mtab}s %s\n" "Exit Status:" "${errorCon}"
	fi
}

wp()
{
	((count++))
	printf "%${mtab}s %s --> %s: %s\n" "Status:" "Pass" "Host" "$ix"
}

wf()
{
	printf "%${mtab}s %s --> %s: %s\n" "Status:" "Fail" "Host" "$ix"
}

webTest()
{
	printf "Spider Web Crawl \n"
	divider
	let count=0
	sites=("www.redhat.com" "www.ubuntu.com" "www.google.com" "www.yahoo.com")

	for ix in ${sites[@]}
	do
		wget -q -t1 -T5 --spider $ix && wp || wf
	done
	printf "\n"
	if ((count >= 1))
	then
	return 0
	fi
}

versionHeader
network
errorStatus
webTest
