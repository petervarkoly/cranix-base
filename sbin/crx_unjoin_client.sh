#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
client=$1
if [ -z "${client}" ]; then
	echo ""
	echo "Usage: crx_dump_dns_domain.sh <client>"
	echo ""
	exit 1
fi
. /etc/sysconfig/cranix
passwd=$( /usr/bin/grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | /usr/bin/sed 's/de.cranix.dao.User.Register.Password=//' )
salt "${client}.${CRANIX_DOMAIN}" system.unjoin_domain domain="${CRANIX_DOMAIN}" username='register' password="${passwd}" restart=True

