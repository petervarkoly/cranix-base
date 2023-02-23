#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
. /etc/sysconfig/cranix
CLIENT=$1
NEWIP=$2
OLDIP=$3

if [ -z ${NEWIP} -o -z ${CLIENT} ]; then
   echo
   echo "Usage crx_change_ip_for_host.sh <Hostname> <Newip> [ <Oldip> ]"
   echo 
   exit 1
fi
passwd=$( /usr/bin/grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | /usr/bin/sed 's/de.cranix.dao.User.Register.Password=//' )

if [ -z $OLDIP ]; then
	OLDIP=$( host $CLIENT | gawk '{ print $4 }' )
fi
samba-tool dns delete localhost $CRANIX_DOMAIN $CLIENT  A $OLDIP   -U register%"$passwd"
samba-tool dns add    localhost $CRANIX_DOMAIN $CLIENT  A $NEWIP   -U register%"$passwd"

