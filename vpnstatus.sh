#!/bin/bash

#############################################################
#
#           script: vpnstatus.sh
#       written by: Marek Novotny
#          version: 2.8
#             date: Mon Dec 28 05:41:00 PST 2015
#          purpose: test status of live vpn connection
#                 : kill torrent if vpn disconnects
#          licence: GPL v2 (only)
#           github: https://github.com/marek-novotny
#           readme:
#
#############################################################

condition=""

sendMessage()
{
  echo "$1" 
}

# apps that should be terminated if VPN fails
processList=("transmission" "firefox" "pan")

# apps that should not be running under vpn
restrictedApps=("thunderbird")  

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
	echo "VPN status: $condition - ${devType[0]}: ${devType[1]}"
	
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
	echo "VPN status: $condition - ${devType[0]}: ${devType[1]}"
	echo "Terminating apps..."

	for x in ${processList[@]} ; do
            task=$x
            processTerminator
	done
	fi
}

randomizer
while true ; do
	devType=($(ip route get $addr | awk 'NR==1 {print $(NF-2),$(NF-0)}'))
	if [[ ${devType[0]} == tun? || ${devType[0]} == ppp? ]] ; then
		vpnOn
	else
		vpnOff
	fi
done

#END
