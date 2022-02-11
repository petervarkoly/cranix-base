#!/bin/bash
# Copyright (c) 2020 Peter Varkoly <pvarkoly@cephalix.eu> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2012-2019 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

MINION=$1
. /etc/sysconfig/cranix
CLIENT=${MINION/.$CRANIX_DOMAIN/}

#Set the license grains
#IFS=$'\n'
LICENCES=$( crx_api_text.sh GET softwares/devicesByName/${CLIENT}/licences )
if [ "${LICENCES:0:7}" = '{"code"' ]; then
                exit
fi
if [ "${LICENCES}" ]; then
        salt "$MINION" grains.setvals ${LICENCES}
fi

#Apply high state
salt "$MINION" state.apply &> /dev/null

#Now we can read the installed software on the minion
/usr/share/cranix/tools/read_installed_software.py $MINION

#Enable or disable windows update if CRANIX_ALLOW_WINDOWS_UPDATES is set
if [ "$CRANIX_ALLOW_WINDOWS_UPDATES" == "yes" ]; then
	salt "$MINION" crx_client.enableUpdates
fi
if [ "$CRANIX_ALLOW_WINDOWS_UPDATES" == "no" ]; then
	salt "$MINION" crx_client.disableUpdates
fi
