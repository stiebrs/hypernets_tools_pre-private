#!/bin/bash - 
#===============================================================================
# #          FILE: webcamGetImg.sh
# 
#         USAGE: ./webcamGetImg.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 28/11/2019 10:53
#      REVISION: v0.2
#===============================================================================


set -o nounset                              # Treat unset variables as an error
set -euo pipefail							# Bash Stict Mode
IFS=$'\n\t'

webcam_site(){
	echo "Sleeping 60s"
	sleep 60 # empirical
	config_sky=$(awk -F "[ =]+" '/webcam_site/ {print $2; exit}' config_hypernets.ini)
	credent_sky=$(echo $config_sky | cut -d "@" -f1)
	ip_sky=$(echo $config_sky | cut -d "@" -f2)
	./webcamGetImg.sh -c "$credent_sky" -i "$ip_sky" -d "WEBCAM/" -wv
	exit 0
}

webcam_sky(){
	echo "Sleeping 75s"
	sleep 75 # empirical
	config_sky=$(awk -F "[ =]+" '/webcam_sky/ {print $2; exit}' config_hypernets.ini)
	credent_sky=$(echo $config_sky | cut -d "@" -f1)
	ip_sky=$(echo $config_sky | cut -d "@" -f2)
	./webcamGetImg.sh -c "$credent_sky" -i "$ip_sky" -d "WEBCAM/" -wv
	python -m hypernets.scripts.relay_command -n6 -soff
	exit 0
}

echo "Opening relay 5"
python -m hypernets.scripts.relay_command -n5 -son
sleep 1
echo "Opening relay 6"
python -m hypernets.scripts.relay_command -n6 -son

webcam_sky &
pid_sky=$!
webcam_site &
pid_site=$!

wait $pid_sky
echo "Closing relay 5"
python -m hypernets.scripts.relay_command -n5 -soff
sleep 1
wait $pid_site
echo "Closing relay 6"
python -m hypernets.scripts.relay_command -n6 -soff
