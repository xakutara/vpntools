#!/bin/bash

#############################################################
#
#           script: vpnstatus.sh
#       written by: Marek Novotny
#          version: 2.9
#             date: Mon Dec 28 04:24PM 2015
#          purpose: test status of live vpn connection
#                 : kill torrent if vpn disconnects
#          licence: GPL v2 (only)
#           github: https://github.com/marek-novotny/vpntools
#
#############################################################

condition=""

# color codes ( best with a black background)

normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)

sendMessage()
{
  echo "$1" 
}

center() 
{
  for i in "${message[@]}"; do
  	width=$(stty size | cut -d' ' -f2)
  	length=${#i}
  	printf "%$(($length+($width-$length)/2))s\n" "${i}"
	done
}

# apps that should be terminated if VPN fails
processList=("transmission" "firefox" "pan")

# apps that should not be running under vpn
restrictedApps=("thunderbird" "slrn")  

# check of a process stored in the variable task is running or not

checkProcess()
{
	unset procID
	procID="$(ps -e | grep $task | grep -v panel | awk '{print $1}')"
	if [ ! -z $procID ] ; then
        return 0
	else
        return 1
	fi
}

# terminate the given process stored in the variable task

terminateProcess()
{
	kill -9 $procID

}

# routine to test for processes, report their status and kill them if running

processTerminator()
{
	checkProcess
	if (($? == 0)) ; then
		sendMessage "$task is running..."
		sendMessage "Terminating $task..."
		terminateProcess
		if (($? == 0)) ; then
			sendMessage "$task terminated..."
		else
			sendMessage "$task is still running..."
		fi
	fi
}

# generate a random IP to test ip route against

randomizer()
{
	IFS=$' '
	ary=()
	for x in {1..4} ; do
		ary+=($(($RANDOM % 221 + 1)))
	done
	
	if [[ ${ary[0]} -eq 10 || ${ary[0]} -eq 100 ]] ; then
		randomizer
	elif [[ ${ary[0]} -eq 169 ]] && [[ ${ary[1]} -eq 254 ]] ; then
		randomizer
	elif [[ ${ary[0]} -eq 172 ]] && [[ ${ary[1]} -eq 16 ]] ; then
		randomizer
	elif [[ ${ary[0]} -eq 192 ]] && [[ ${ary[1]} -eq 168 ]] ; then
		randomizer
	elif [[ ${ary[0]} -eq 198 ]] && [[ ${ary[1]} -eq 18 ]] ; then
		randomizer
	else
		addr=$(echo "${ary[@]}" | awk '{print $1"."$2"."$3"."$4}')
	fi
}

# kill apps that should not be running if VPN is connected.
# kills these apps once, if the script is running and the VPN
# tunnel becomes active

vpnOn()
{
	if [[ $condition != "on" ]] ; then
	condition="on"
	echo "VPN status: $green $condition $normal- ${devType[0]}: ${devType[1]}"
	
	for x in ${restrictedApps[@]} ; do
		task=$x
		processTerminator
	done
	fi
}

# drop apps that should not be running if vpn tunnel fails

vpnOff()
{
	if [[ $condition != "off" ]] ; then
	condition="off"
	echo "VPN status: $red $condition $normal- ${devType[0]}: ${devType[1]}"
	echo "Terminating apps..."

	for x in ${processList[@]} ; do
            task=$x
            processTerminator
	done
	fi
}

checkStatus()
{
	while true ; do
		devType=($(ip route get $addr | awk 'NR==1 {print $(NF-2),$(NF-0)}'))
		if [[ ${devType[0]} == "$devVPN" ]] ; then
			vpnOn
		else
			vpnOff
		fi
	done
}

detectVPN()
{
	devVPN=$(ip route get $addr | awk 'NR==1 {print $(NF-2)}')

	successful=("" "you've been assigned the device: $blue $devVPN $normal" ""
	"the script will alert you and take action if"
	"the vpn provided device: $devVPN drops at any time" "")

	failure=("$red" "we didn't detect any difference and believe you will"
	"need to try the detection phase again..." ""
	"sorry for the inconvenience..." "$normal"
	"$green" "press any key to begin the detection over again..." "$normal")

	if [ "$devNorm" != "$devVPN" ] ; then
		message=( "${successful[@]}" )
		clear
		center
		checkStatus
		else
		message=( "${failure[@]}" )
		clear
		center
		read -rs -n1 key
		intro
	fi
}

detectNormal()
{
	devNorm=$(ip route get $addr | awk 'NR==1 {print $(NF-2)}')

	message=("" "default device detected as:$blue $devNorm $normal" ""
	"now we're going to determine the name of the tunnel"
	"your vpn provider will use while connected to their vpn service" ""
	"connect to your vpn provider now, and once connected..." "$green"
	"press any key to continue" "$normal")
	
	clear
	center
	read -rs -n1 key
	unset message
	detectVPN
}

intro()
{		
	message=("" "welcome to vpnStatus" "----------------------------" ""
	"this script needs to determine your default device name"
	"and the vpn device name assigned by your provider" ""
	"to do that we need to run two tests and compare the results" ""
	"if you are not already disconnected from your vpn provider, disconnect now" "$green"
	"press any key to continue" "$normal")
	
	clear
	center
	read -rs -n1 key
	unset message
	randomizer
	detectNormal
}

intro

#END
