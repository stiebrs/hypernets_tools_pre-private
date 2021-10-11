#!/bin/bash -
#===============================================================================
#
#          FILE: run_service.sh
#
#         USAGE: ./run_service.sh
#
#   DESCRIPTION: Script called by systemd to run a sequence at boot time # #       
#       OPTIONS: ---
#        AUTHOR: Alexandre CORIZZI, alexandre.corizzi@obs-vlfr.fr
#  ORGANIZATION: Laboratoire d'oceanographie de Villefranche-sur-mer (LOV)
#       CREATED: 22/10/2020 18:19
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error
set -euo pipefail                           # Bash Strict Mode


if [[ ${PWD##*/} != "hypernets_tools" ]]; then
	echo "This script must be run from hypernets_tools folder" 1>&2
	echo "Use : ./utils/${0##*/} instead"
	exit 1
fi


source utils/configparser.sh

baudrate=$(parse_config "baudrate" config_dynamic.ini)
hypstarPort=$(parse_config "'hypstar_port" config_dynamic.ini)
bypassYocto=$(parse_config "bypass_yocto" config_static.ini)
loglevel=$(parse_config "loglevel" config_dynamic.ini)
bootTimeout=$(parse_config "boot_timeout" config_dynamic.ini)
swirTec=$(parse_config "swir_tec" config_dynamic.ini)

startSequence=$(parse_config "start_sequence" config_dynamic.ini)

extra_args=""
if [[ "$startSequence" == "no" ]] ; then
	echo "Start sequence = no"
	shutdown_sequence;
fi

if [[ -n $hypstarPort ]] ; then
	extra_args="$extra_args -p $hypstarPort"
fi

if [[ -n $baudrate ]] ; then
	extra_args="$extra_args -b $baudrate"
fi

if [[ -n $loglevel ]] ; then
	extra_args="$extra_args -l $loglevel"
fi

if [[ -n $bootTimeout ]] ; then
	extra_args="$extra_args -t $bootTimeout"
fi

if [[ -n $swirTec ]] ; then
	extra_args="$extra_args -T $swirTec"
fi

if [[ "$bypassYocto" == "no" ]] ; then

	# Ensure Yocto is online
	yoctopuceIP=$(parse_config "yoctopuce_ip" config_static.ini)

	if [[ ! "$yoctopuceIP" == "usb" ]] ; then
		# We ping it if there is an IP address
		echo "Waiting for yoctopuce..."
		while ! timeout 2 ping -c 1 -n $yoctopuceIP &>/dev/null
		do
			echo -n '.'
		done
		echo "Ok !"
	else
		# Else check  if VirtualHub is running
		set +e
		systemctl is-active yvirtualhub.service > /dev/null
		set -e
		if [[ $? -eq 0 ]] ; then
			echo "[INFO]  VirtualHub is running."
		else
			echo "[INFO]  Starting VirtualHub..."
			/usr/bin/VirtualHub
			sleep 2
			echo "ok"
		fi
	fi

	python -m hypernets.yocto.relay -son -n2 -n3

else
	echo "Bypassing Yocto"
    extra_args="$extra_args --noyocto"
fi

sequence_file=$(parse_config "sequence_file" config_dynamic.ini)

shutdown_sequence() {
    if [[ "$bypassYocto" == "no" ]] ; then
	    python -m hypernets.yocto.relay -soff -n2 -n3
    fi

    keepPc=$(parse_config "keep_pc" config_dynamic.ini)

    if [[ "$keepPc" == "off" ]]; then
	    echo "Option : Keep PC OFF"
	    # Send Yoctopuce To sleep (or not)
	    python -m hypernets.yocto.sleep_monitor
	    exit 0
    else
	    # Cause service exit 1 and doesnt execute SuccessAction=poweroff
	    echo "Option : Keep PC ON"
	    exit 1
    fi
}

exit_actions() {
    return_value=$?
    if [ $return_value -eq 0 ] ; then
        echo "Success"
    else
    	echo "Hysptar scheduled job exited with code $return_value";
		echo "Second try : "
		set +e
		python3 -m hypernets.open_sequence -f $sequence_file $extra_args
		set -e
    fi
	shutdown_sequence;
}

trap "exit_actions" EXIT
python3 -m hypernets.open_sequence -f $sequence_file $extra_args
