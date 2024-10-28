#!/bin/bash

# This script is run without root privilege
# inside the container when it is started.

script_dir=$(dirname -- "$(readlink -nf $0)";)
source "$script_dir/header.sh"
validate_linux

if [[ -z "$DISPLAY" ]]; then f_echo "DISPLAY is not set."; exit 1; fi
if [[ -z "$XAUTH_COOKIE" ]]; then f_echo "XAUTH_COOKIE is not set."; exit 1; fi

# Extract the hostname and display number from the DISPLAY variable
REMOTE=$(echo $DISPLAY | awk -F':' '{print $1}')
DISP_NUM=$(echo $DISPLAY | awk -F':' '{print $2}')
if [[ -z "$REMOTE" ]]; then f_echo "DISPLAY is not set correctly (no host name)."; exit 1; fi
if [[ -z "$DISP_NUM" ]]; then f_echo "DISPLAY is not set correctly (no display number)."; exit 1; fi

DISP_PORT=$((6000 + $DISP_NUM))

# Check if the X server is listeming on the port
NC=$(nc -zv $REMOTE $DISP_PORT 2>&1 | grep 'Connection to .* succeeded!')
if [[ -z "$NC" ]]; then f_echo "Unable to connect to the X server."; exit 1; fi

export LD_PRELOAD="/lib/x86_64-linux-gnu/libudev.so.1 /lib/x86_64-linux-gnu/libselinux.so.1 /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libgdk-x11-2.0.so.0"
xauth add $DISPLAY . $XAUTH_COOKIE

# if Vivado is installed
if [[ -d "/home/user/Xilinx" ]]; then
    cd /home/user
	# Make Vivado connect to the xvcd server running on macOS
	/home/user/Xilinx/Vivado/*/bin/hw_server -e "set auto-open-servers     xilinx-xvc:$REMOTE:2542" &
	/home/user/Xilinx/Vivado/*/settings64.sh
	f_echo "Start Vivado..."
	/home/user/Xilinx/Vivado/*/bin/vivado
else
	f_echo "The installation is incomplete."
fi
