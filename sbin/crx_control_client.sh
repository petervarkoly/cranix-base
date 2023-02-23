#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

client=$1
action=$2

if [ -z "${client}" -o -z "${action}" ]; then
	echo ""
	echo "usage: crx_control_client.sh ClientName Action"
	echo ""
	echo "Actions: open close reboot shutdown wol logout unlockInput lockInput cleanUpLoggedIn"
	echo ""
	exit 1
fi
/usr/sbin/crx_api.sh PUT devices/byName/${client}/actions/${action}

